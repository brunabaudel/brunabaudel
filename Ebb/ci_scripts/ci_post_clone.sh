#!/bin/sh
set -eu

# Runs after Xcode Cloud clones the repository.
# See Ebb/XCODE_CLOUD_SETUP.md for workflow configuration.

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ]; then
  exit 0
fi

echo "Xcode Cloud post-clone"
echo "  workflow: ${CI_WORKFLOW:-unknown}"
echo "  branch:   ${CI_BRANCH:-unknown}"
echo "  commit:   ${CI_COMMIT:-unknown}"
echo "  product:  ${CI_PRODUCT:-unknown}"
