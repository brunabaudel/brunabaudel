#!/usr/bin/env bash
# Writes inline screenshot previews and artifact instructions to GITHUB_STEP_SUMMARY.
set -euo pipefail

SCREENS_DIR="${1:-screenshots}"
RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

if [[ ! -d "$SCREENS_DIR" ]]; then
  echo "Screenshot directory not found: $SCREENS_DIR" >&2
  exit 1
fi

{
  echo "## App screenshots"
  echo ""
  echo "Captured on the iOS Simulator during this workflow run."
  echo ""
  echo "**Download all:** open the [**Artifacts** section](${RUN_URL}#artifacts) on this run and download \`screenshots\`."
  echo ""

  shopt -s nullglob
  for png in "$SCREENS_DIR"/*.png; do
    name="$(basename "$png" .png)"
    title="${name//-/ }"
    title="$(echo "$title" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
    echo "### ${title}"
    echo ""
    echo "![](data:image/png;base64,$(base64 < "$png" | tr -d '\n'))"
    echo ""
  done
} >> "$GITHUB_STEP_SUMMARY"
