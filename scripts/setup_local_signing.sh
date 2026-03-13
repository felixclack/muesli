#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IDENTITY_NAME="${MUESLI_LOCAL_SIGNING_IDENTITY:-Muesli Local Development}"
KEYCHAIN_PATH="${MUESLI_LOCAL_SIGNING_KEYCHAIN:-${HOME}/Library/Keychains/muesli-local-signing.keychain-db}"
KEYCHAIN_PASSWORD="${MUESLI_LOCAL_SIGNING_KEYCHAIN_PASSWORD:-muesli-local-signing}"

ensure_keychain_search_list() {
  local existing_keychains=()

  while IFS= read -r keychain; do
    [[ -n "${keychain}" ]] || continue
    [[ "${keychain}" == "${KEYCHAIN_PATH}" ]] && continue
    existing_keychains+=("${keychain}")
  done < <(find "${HOME}/Library/Keychains" -maxdepth 1 -type f \( -name '*.keychain-db' -o -name '*.keychain' \) | sort)

  security list-keychains -d user -s "${KEYCHAIN_PATH}" "${existing_keychains[@]}" >/dev/null
}

identity_hash_candidates() {
  security find-certificate -a -Z "${KEYCHAIN_PATH}" 2>/dev/null | awk -v name="${IDENTITY_NAME}" '
    /^SHA-256 hash:/ {
      if (seen && label == name && sha1 != "") {
        print sha1
      }
      seen = 1
      label = ""
      sha1 = ""
      next
    }
    /^SHA-1 hash:/ {
      sha1 = $3
      next
    }
    /"labl"<blob>=/ {
      label = $0
      sub(/^.*"labl"<blob>="/, "", label)
      sub(/".*$/, "", label)
      next
    }
    END {
      if (seen && label == name && sha1 != "") {
        print sha1
      }
    }
  '
}

signing_hash_for_identity() {
  local hash tmpdir probe_path

  while read -r hash; do
    [[ -n "${hash}" ]] || continue

    tmpdir="$(mktemp -d)"
    probe_path="${tmpdir}/probe"
    cp /bin/echo "${probe_path}"

    if codesign --force --keychain "${KEYCHAIN_PATH}" --sign "${hash}" "${probe_path}" >/dev/null 2>&1; then
      rm -rf "${tmpdir}"
      printf '%s\n' "${hash}"
      return 0
    fi

    rm -rf "${tmpdir}"
  done < <(identity_hash_candidates)

  return 1
}

can_sign_with_identity() {
  local tmpdir probe_path

  signing_hash_for_identity >/dev/null
}

if can_sign_with_identity; then
  echo "Local signing identity is ready: ${IDENTITY_NAME}"
  exit 0
fi

if [[ ! -f "${KEYCHAIN_PATH}" ]]; then
  security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}" >/dev/null
fi
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}" >/dev/null
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}" >/dev/null
ensure_keychain_search_list

if can_sign_with_identity; then
  echo "Local signing identity is ready: ${IDENTITY_NAME}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

pkcs12_password="$(openssl rand -hex 24)"

cat > "${tmpdir}/openssl.cnf" <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_codesign

[ dn ]
CN = ${IDENTITY_NAME}
O = Felix Clack Local Development
OU = Muesli
C = GB

[ v3_codesign ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyCertSign
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -days 3650 \
  -config "${tmpdir}/openssl.cnf" \
  -keyout "${tmpdir}/key.pem" \
  -out "${tmpdir}/cert.pem" \
  >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -inkey "${tmpdir}/key.pem" \
  -in "${tmpdir}/cert.pem" \
  -out "${tmpdir}/local-signing.p12" \
  -passout "pass:${pkcs12_password}" \
  >/dev/null 2>&1

security import "${tmpdir}/local-signing.p12" \
  -k "${KEYCHAIN_PATH}" \
  -P "${pkcs12_password}" \
  -A \
  -t agg \
  -f pkcs12 \
  >/dev/null

security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "${KEYCHAIN_PASSWORD}" \
  "${KEYCHAIN_PATH}" \
  >/dev/null

if ! can_sign_with_identity; then
  echo "Created ${IDENTITY_NAME}, but codesign still cannot use it." >&2
  exit 1
fi

echo "Local signing identity is ready: ${IDENTITY_NAME}"
