#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f config/local.json ]]; then
  echo "Missing config/local.json. Copy config/local.example.json and add the Web OAuth client ID." >&2
  exit 1
fi
if grep -q "YOUR_WEB_CLIENT_ID" config/local.json; then
  echo "Replace the placeholder in config/local.json with your Web OAuth client ID." >&2
  exit 1
fi

flutter build apk --dart-define-from-file=config/local.json "$@"
