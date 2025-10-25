#!/bin/bash

STATE_FILE="$HOME/.cache/kitty_spawn_index"
MAX_POS=9

# Read last position
if [[ -f "$STATE_FILE" ]]; then
  POS=$(<"$STATE_FILE")
else
  POS=0
fi

# --- Monitor info (active focused monitor) ---
# hyprctl monitors --j | jq
MON_DATA=$(hyprctl -j monitors | jq '.[] | select(.focused==true)')
SCREEN_W=$(echo "$MON_DATA" | jq -r '.width')
SCREEN_H=$(echo "$MON_DATA" | jq -r '.height')
MON_X=$(echo "$MON_DATA" | jq -r '.x')
MON_Y=$(echo "$MON_DATA" | jq -r '.y')

# --- Desired window size ---
WIN_W=1275
WIN_H=1000

# Column/row calc
COL=$((POS / 3))
ROW=$((POS % 3))

case $COL in
0) # center column
  X=$((MON_X + (SCREEN_W / 3) + ((SCREEN_W / 3 - WIN_W) / 2))) ;;
1) # left column
  X=$((MON_X + (0) + ((SCREEN_W / 3 - WIN_W) / 2))) ;;
2) # right column
  X=$((MON_X + (2 * SCREEN_W / 3) + ((SCREEN_W / 3 - WIN_W) / 2))) ;;
esac

Y=$((MON_Y + ROW * (SCREEN_H / 3) + ((SCREEN_H / 3 - WIN_H) / 2)))

# --- Launch kitty ---
kitty &

# Wait briefly for the window to map
sleep 0.3

# Resize and move last focused (new kitty)
hyprctl dispatch resizewindowpixel exact "$WIN_W" "$WIN_H"
hyprctl dispatch movewindowpixel exact "$X" "$Y"

# Increment position and wrap
POS=$(((POS + 1) % MAX_POS))
echo "$POS" >"$STATE_FILE"
