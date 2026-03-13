#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"
if [[ -f .env.fastlane ]]; then
  # Load ignored local Fastlane credentials for repeatable signing runs on this Mac.
  source .env.fastlane
fi

if command -v fastlane >/dev/null 2>&1; then
  exec fastlane "$@"
fi

if command -v bundle >/dev/null 2>&1; then
  export BUNDLE_PATH="${BUNDLE_PATH:-${ROOT_DIR}/vendor/bundle}"
  export BUNDLE_DISABLE_SHARED_GEMS="${BUNDLE_DISABLE_SHARED_GEMS:-1}"
  exec bundle exec fastlane "$@"
fi

echo "fastlane is not installed and bundler is unavailable." >&2
exit 1
