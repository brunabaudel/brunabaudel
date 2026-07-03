#!/usr/bin/env bash
# Configure GitHub Actions secrets/variables for TestFlight CI.
#
# 1. Copy setup-secrets.env.example → setup-secrets.env
# 2. Fill in your Apple Developer / App Store Connect values
# 3. Run: ./scripts/configure-github-secrets.sh
#
# Requires: GitHub CLI (gh) authenticated with repo admin access.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/setup-secrets.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Copy setup-secrets.env.example to setup-secrets.env and fill in your values."
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

required=(DEVELOPMENT_TEAM APPSTORE_ISSUER_ID APPSTORE_API_KEY_ID APPSTORE_API_PRIVATE_KEY)
for var in "${required[@]}"; do
  if [[ -z "${!var:-}" || "${!var}" == *"XXXXXXXX"* || "${!var}" == *"..."* ]]; then
    echo "Please set a real value for $var in $ENV_FILE"
    exit 1
  fi
done

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

echo "Setting GitHub secrets and variables for $(gh repo view --json nameWithOwner -q .nameWithOwner)..."

gh secret set DEVELOPMENT_TEAM --body "$DEVELOPMENT_TEAM"
gh secret set APPSTORE_API_PRIVATE_KEY --body "$APPSTORE_API_PRIVATE_KEY"
gh secret set KEYCHAIN_PASSWORD --body "$KEYCHAIN_PASSWORD"

gh variable set APPSTORE_ISSUER_ID --body "$APPSTORE_ISSUER_ID"
gh variable set APPSTORE_API_KEY_ID --body "$APPSTORE_API_KEY_ID"

echo ""
echo "Done. GitHub is configured for TestFlight CI."
echo ""
echo "Next steps:"
echo "  1. Merge the branch with the workflow (or push to app/ebb / main)"
echo "  2. Actions → TestFlight → Run workflow → choose 'Register app with Apple' if first time"
echo "  3. Run 'Deploy to TestFlight' (or push again) to build and upload"
echo "  4. Install BasicApp from the TestFlight app on your iPhone"
