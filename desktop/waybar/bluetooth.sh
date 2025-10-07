#!/bin/bash

# Get Bluetooth status
if ! bluetoothctl show | grep -q "Powered: yes"; then
  ICON="󰂲" # Bluetooth off
elif bluetoothctl info | grep -q "Connected: yes"; then
  ICON="󰂱" # Connected
else
  ICON="󰂯" # On but not connected
fi

# Output JSON for Waybar
echo "{\"icon\": \"$ICON\"}"
