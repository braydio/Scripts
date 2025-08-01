#!/bin/bash

set -euo pipefail

echo "🔍 Scanning for Bluetooth dongles..."
BT_DONGLE=$(lsusb | grep -i bluetooth || true)

if [[ -z "$BT_DONGLE" ]]; then
  echo "❌ No Bluetooth dongle found via lsusb"
  exit 1
fi

echo "✅ Found dongle: $BT_DONGLE"
echo

echo "📂 Checking USB bus and power settings..."
lsusb -t

echo "🧼 Checking dmesg for related errors..."
dmesg | grep -i -E 'usb|blue|hid' | tail -n 30

echo "⚙️ Listing current input devices:"
ls -l /dev/input/by-id/ | grep -i bluetooth || true

echo "🔌 Disabling USB autosuspend for Bluetooth dongles..."

for DEV in $(find /sys/bus/usb/devices/usb*/power/level); do
  echo "on" >"$DEV" 2>/dev/null || true
done

echo "🧯 Forcing high polling rate (1ms) if device supports it..."
for dev in /sys/module/hid*/parameters/mousepoll; do
  echo 1 >"$dev" 2>/dev/null || true
done

echo
echo "🧪 Testing responsiveness. Move your mouse/keyboard now..."
sleep 5
echo "Done."

read -rp "Run live Bluetooth event monitor (btmon)? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  btmon
fi
