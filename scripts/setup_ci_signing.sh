#!/bin/bash

set -euo pipefail

required_vars=(
  APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64
  APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD
  CI_KEYCHAIN_PASSWORD
  CI_KEYCHAIN_PATH
)

for variable_name in "${required_vars[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Missing required environment variable: ${variable_name}" >&2
    exit 1
  fi
done

certificate_path="$(mktemp "${TMPDIR:-/tmp}/muesli-developer-id.XXXXXX.p12")"
trap 'rm -f "${certificate_path}"' EXIT

printf '%s' "${APPLE_DEVELOPER_ID_CERTIFICATE_P12_BASE64}" | /usr/bin/base64 -D > "${certificate_path}"

security create-keychain -p "${CI_KEYCHAIN_PASSWORD}" "${CI_KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${CI_KEYCHAIN_PATH}"
security unlock-keychain -p "${CI_KEYCHAIN_PASSWORD}" "${CI_KEYCHAIN_PATH}"
security import "${certificate_path}" \
  -P "${APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD}" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "${CI_KEYCHAIN_PATH}"
security set-key-partition-list -S apple-tool:,apple: -s -k "${CI_KEYCHAIN_PASSWORD}" "${CI_KEYCHAIN_PATH}"
security list-keychains -d user -s "${CI_KEYCHAIN_PATH}"
security default-keychain -d user -s "${CI_KEYCHAIN_PATH}"
security find-identity -v -p codesigning "${CI_KEYCHAIN_PATH}"
