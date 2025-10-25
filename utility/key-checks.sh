#!/usr/bin/env bash
#
# map-scancodes.sh
# Run evtest on a device and build a scancode → keycode map.
# Flags unmapped scancodes (*** in libinput).
#
# Usage: sudo ./map-scancodes.sh /dev/input/eventX
#

DEVICE=$1
if [[ -z "$DEVICE" ]]; then
  echo "Usage: $0 /dev/input/eventX"
  exit 1
fi

echo "[*] Listening on $DEVICE ..."
echo "    Press keys you want to test (Ctrl+C to stop)"
echo

# Run evtest and capture only scan+key lines
timeout 20s evtest "$DEVICE" 2>/dev/null |
  grep -E "MSC_SCAN|EV_KEY" |
  awk '
  /MSC_SCAN/ { scancode=$NF }
  /EV_KEY/ {
    if ($5=="code") {
      code=$6; key=$7
      if (scancode != "") {
        printf "%-8s → %-12s (%s)\n", scancode, key, code
        scancode=""
      }
    }
  }'
