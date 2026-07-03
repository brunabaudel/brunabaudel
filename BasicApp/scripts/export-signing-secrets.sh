#!/usr/bin/env bash
# Run once on a Mac to print GitHub secret values for TestFlight CI.
# Usage: ./scripts/export-signing-secrets.sh /path/to/cert.p12 /path/to/profile.mobileprovision

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <distribution-cert.p12> <app-store-profile.mobileprovision>"
  echo ""
  echo "Create these in Apple Developer / App Store Connect:"
  echo "  1. Apple Distribution certificate exported as .p12"
  echo "  2. App Store provisioning profile for com.brunabaudel.BasicApp"
  exit 1
fi

CERT_PATH="$1"
PROFILE_PATH="$2"

if [[ ! -f "$CERT_PATH" ]]; then
  echo "Certificate not found: $CERT_PATH"
  exit 1
fi

if [[ ! -f "$PROFILE_PATH" ]]; then
  echo "Provisioning profile not found: $PROFILE_PATH"
  exit 1
fi

echo ""
echo "Add these GitHub repository secrets (Settings → Secrets and variables → Actions):"
echo ""
echo "BUILD_CERTIFICATE_BASE64"
base64 < "$CERT_PATH" | tr -d '\n'
echo ""
echo ""
echo "BUILD_PROVISION_PROFILE_BASE64"
base64 < "$PROFILE_PATH" | tr -d '\n'
echo ""
echo ""
echo "Also add:"
echo "  P12_PASSWORD          — password used when exporting the .p12"
echo "  KEYCHAIN_PASSWORD     — any random string (used only in CI)"
echo "  DEVELOPMENT_TEAM      — your 10-character Apple Team ID"
echo "  APPSTORE_API_PRIVATE_KEY — contents of your App Store Connect .p8 API key"
echo ""
echo "And these repository variables (Settings → Secrets and variables → Actions → Variables):"
echo "  APPSTORE_ISSUER_ID"
echo "  APPSTORE_API_KEY_ID"
echo ""
