#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/build/LocalInstallDerivedData"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/Muesli.app"
INSTALL_PATH="/Applications/Muesli.app"
LOCAL_IDENTITY_NAME="${MUESLI_LOCAL_SIGNING_IDENTITY:-Muesli Local Development}"
LOCAL_KEYCHAIN_PATH="${MUESLI_LOCAL_SIGNING_KEYCHAIN:-${HOME}/Library/Keychains/muesli-local-signing.keychain-db}"
LOCAL_KEYCHAIN_PASSWORD="${MUESLI_LOCAL_SIGNING_KEYCHAIN_PASSWORD:-muesli-local-signing}"

ensure_local_keychain_search_list() {
  local existing_keychains=()

  while IFS= read -r keychain; do
    [[ -n "${keychain}" ]] || continue
    [[ "${keychain}" == "${LOCAL_KEYCHAIN_PATH}" ]] && continue
    existing_keychains+=("${keychain}")
  done < <(find "${HOME}/Library/Keychains" -maxdepth 1 -type f \( -name '*.keychain-db' -o -name '*.keychain' \) | sort)

  security list-keychains -d user -s "${LOCAL_KEYCHAIN_PATH}" "${existing_keychains[@]}" >/dev/null
}

first_identity() {
  local prefix="${1}"

  security find-identity -v -p codesigning 2>/dev/null \
    | sed -nE "s/.*\"(${prefix}:[^\"]+)\".*/\\1/p" \
    | head -n 1
}

local_identity_hash() {
  local hash tmpdir probe_path

  while read -r hash; do
    [[ -n "${hash}" ]] || continue

    tmpdir="$(mktemp -d)"
    probe_path="${tmpdir}/probe"
    cp /bin/echo "${probe_path}"

    if codesign --force --keychain "${LOCAL_KEYCHAIN_PATH}" --sign "${hash}" "${probe_path}" >/dev/null 2>&1; then
      rm -rf "${tmpdir}"
      printf '%s\n' "${hash}"
      return 0
    fi

    rm -rf "${tmpdir}"
  done < <(
    security find-certificate -a -Z "${LOCAL_KEYCHAIN_PATH}" 2>/dev/null | awk -v name="${LOCAL_IDENTITY_NAME}" '
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
  )

  return 1
}

signing_identity="${MUESLI_INSTALL_SIGNING_IDENTITY:-}"
signing_identity_label="${signing_identity}"
if [[ -z "${signing_identity}" ]]; then
  signing_identity="$(first_identity "Developer ID Application")"
  signing_identity_label="${signing_identity}"
fi
if [[ -z "${signing_identity}" ]]; then
  signing_identity="$(first_identity "Apple Distribution")"
  signing_identity_label="${signing_identity}"
fi
if [[ -z "${signing_identity}" ]]; then
  signing_identity="$(first_identity "Apple Development")"
  signing_identity_label="${signing_identity}"
fi
if [[ -z "${signing_identity}" ]]; then
  if [[ -f "${LOCAL_KEYCHAIN_PATH}" ]]; then
    security unlock-keychain -p "${LOCAL_KEYCHAIN_PASSWORD}" "${LOCAL_KEYCHAIN_PATH}" >/dev/null 2>&1 || true
    ensure_local_keychain_search_list
  fi
  local_identity_signing_hash="$(local_identity_hash || true)"
  if [[ -n "${local_identity_signing_hash}" ]]; then
    signing_identity="${local_identity_signing_hash}"
    signing_identity_label="${LOCAL_IDENTITY_NAME}"
  fi
fi

echo "Building a clean local app bundle..."
xcodebuild \
  -project "${ROOT_DIR}/Muesli.xcodeproj" \
  -scheme Muesli \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  clean \
  build

if [[ -z "${signing_identity}" ]]; then
  echo "No stable signing identity detected; installing the ad hoc-signed build." >&2
  echo "Run scripts/setup_local_signing.sh to create a repeatable local identity for permission testing." >&2
  echo "macOS permissions are less likely to persist across reinstalls with ad hoc signatures." >&2
else
  echo "Re-signing app with ${signing_identity_label:-${signing_identity}}..."
  if [[ "${signing_identity_label:-}" == "${LOCAL_IDENTITY_NAME}" ]]; then
    codesign --force --deep --keychain "${LOCAL_KEYCHAIN_PATH}" --sign "${signing_identity}" "${APP_PATH}"
  else
    codesign --force --deep --sign "${signing_identity}" "${APP_PATH}"
  fi
fi

echo "Installing to ${INSTALL_PATH}..."
pkill -x Muesli >/dev/null 2>&1 || true
rm -rf "${INSTALL_PATH}"
ditto "${APP_PATH}" "${INSTALL_PATH}"

echo "Launching ${INSTALL_PATH}..."
open -a "${INSTALL_PATH}"
codesign -dv --verbose=4 "${INSTALL_PATH}" 2>&1 | sed -n '1,20p'
