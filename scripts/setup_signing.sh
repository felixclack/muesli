#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"
if [[ -f .env.fastlane ]]; then
  # Load ignored local Fastlane credentials for repeatable signing runs on this Mac.
  source .env.fastlane
fi
exec fastlane mac setup_signing
