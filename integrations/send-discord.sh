#!/bin/bash

DRY_RUN=0 # set to 1 to check window only

TARGET_SUBSTRING="discord"
COMMAND="Continue the task per the instructions in the log. If you have not done so, update the public and personal logs. Do not change any existing files outside of /scripts/ in the root braydio/pyNance directory"

# Find matching window
MATCHED=$()

if [[ -z "$MATCHED" ]]; then
  echo "❌ No window found containing: '$TARGET_SUBSTRING'"
  exit 1
else
  echo "✅ Found window: $MATCHED"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    exit 0
  fi
fi

# Loop every 33 seconds
while true; do
  echo "Focusing window..."
  hyprctl dispatch focuswindow address:$MATCHED
  sleep 1.5

  echo "Entering insert mode..."
  echo -n "i" | sudo ydotool type --file -
  sleep 1.2

  echo "Typing command..."
  echo "$COMMAND" | sudo ydotool type --file -
  sleep 0.5

  echo "Sending ENTER..."
  sudo ydotool key 28
  sleep 0.5

  echo "Sending exit keys: ESC, f, j, k..."
  sudo ydotool key 1 # ESC
  sleep 0.1
  sudo ydotool key 33 # f
  sudo ydotool key 36 # j
  sudo ydotool key 37 # k

  sleep 33
done
