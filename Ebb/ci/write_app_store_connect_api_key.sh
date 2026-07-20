#!/usr/bin/env bash
# Writes the App Store Connect API key where Spaceship and xcodebuild expect it.
# Used by Codemagic (env group ebb_apple_credentials) and reusable in other CI.
set -euo pipefail

KEY_ID="${APP_STORE_CONNECT_KEY_IDENTIFIER:-${APPSTORE_API_KEY_ID:-}}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-${APPSTORE_ISSUER_ID:-}}"
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY:-}"

if [[ -z "$KEY_ID" || -z "$ISSUER_ID" || -z "$PRIVATE_KEY" ]]; then
  echo "Missing App Store Connect API credentials."
  echo "Set APP_STORE_CONNECT_KEY_IDENTIFIER, APP_STORE_CONNECT_ISSUER_ID,"
  echo "and APP_STORE_CONNECT_PRIVATE_KEY (see Ebb/CODEMAGIC_SETUP.md)."
  exit 1
fi

export APPSTORE_API_KEY_ID="$KEY_ID"
export APPSTORE_ISSUER_ID="$ISSUER_ID"

KEY_DIR="$HOME/.appstoreconnect/private_keys"
KEY_FILE="$KEY_DIR/AuthKey_${KEY_ID}.p8"
mkdir -p "$KEY_DIR"
printf '%s\n' "$PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

if ! grep -q "BEGIN PRIVATE KEY" "$KEY_FILE"; then
  echo "APP_STORE_CONNECT_PRIVATE_KEY is missing BEGIN PRIVATE KEY header"
  exit 1
fi

echo "Wrote App Store Connect API key to $KEY_FILE"
