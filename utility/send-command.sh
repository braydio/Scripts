#!/bin/bash

DRY_RUN=0
TARGET_SUBSTRING="Repo Organization Recommendations"
COMMAND="Continue the task per the instructions in the log. If you have not done so, update the public and personal logs. Do not change any existing files outside of /scripts/ in the root braydio/pyNance directory"

# Slower typing function
type_slowly() {
  local str="$1"
  for ((i = 0; i < ${#str}; i++)); do
    char="${str:$i:1}"
    printf "%s" "$char" | sudo ydotool type --file -
    sleep 0.06 # 60ms delay per char
  done
}

# Find window
MATCHED=$(hyprctl clients -j | jq -r ".[] | select(.title | test(\"$TARGET_SUBSTRING\"; \"i\")) | .address")

if [[ -z "$MATCHED" ]]; then
  echo "❌ No window found matching '$TARGET_SUBSTRING'"
  exit 1
else
  echo "✅ Found window: $MATCHED"
  [[ "$DRY_RUN" -eq 1 ]] && exit 0
fi

while true; do
  echo "🔍 Focusing target window..."
  hyprctl dispatch focuswindow address:$MATCHED
  sleep 1.5

  echo "🎯 Triggering qutebrowser hint mode..."
  sudo ydotool key 33 # f
  sleep 1.2
  sudo ydotool key 37 # k (select input field)
  sleep 1.5

  echo "📝 Entering insert mode..."
  echo -n "i" | sudo ydotool type --file -
  sleep 1.2

  echo "⌨️ Typing message..."
  type_slowly "$COMMAND"
  sleep 0.5

  echo "⏎ Sending ENTER..."
  sudo ydotool key 28
  sleep 0.5

  echo "🚪 Exiting insert mode and resetting..."
  sudo ydotool key 1 # ESC
  sleep 0.2
  sudo ydotool key 36 # j
  sudo ydotool key 37 # k

  sleep 33
done
