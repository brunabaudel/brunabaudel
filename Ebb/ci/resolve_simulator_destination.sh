#!/usr/bin/env bash
# Picks an available iPhone simulator for xcodebuild -destination.
set -euo pipefail

preferred=(
  "iPhone 17"
  "iPhone 16 Pro"
  "iPhone 16"
  "iPhone 15 Pro"
  "iPhone 15"
)

while IFS= read -r line; do
  for name in "${preferred[@]}"; do
    if [[ "$line" == *"${name} ("* && "$line" != *"(unavailable)"* ]]; then
      echo "platform=iOS Simulator,name=${name}"
      exit 0
    fi
  done
done < <(xcrun simctl list devices available)

# Last resort: first bootable iPhone entry from simctl JSON.
python3 - <<'PY'
import json, subprocess, sys

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
for runtime in sorted(data["devices"], reverse=True):
    for device in data["devices"][runtime]:
        if not device.get("isAvailable"):
            continue
        name = device["name"]
        if name.startswith("iPhone"):
            print(f"platform=iOS Simulator,name={name}")
            sys.exit(0)

print("No available iPhone simulator found", file=sys.stderr)
sys.exit(1)
PY
