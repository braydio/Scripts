#!/bin/bash

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo -e "
move_workspace_windows_safe.sh  —  Move all windows from one Hyprland workspace to another
Preserves floating window layout. Handles occupied destination workspace by offloading windows to a holding workspace.

USAGE:
  move_workspace_windows_safe.sh <from_ws_id> <to_ws_id> [holding_ws_id]

ARGS:
  <from_ws_id>      Workspace to move windows FROM (e.g. 2)
  <to_ws_id>        Workspace to move windows TO (e.g. 3)
  [holding_ws_id]   (Optional) Workspace to move existing TO windows to first. Defaults to 99.

EXAMPLES:
  move_workspace_windows_safe.sh 2 3
      Moves all windows from workspace 2 → 3.
      If 3 has windows, they'll be moved to workspace 99 first.

  move_workspace_windows_safe.sh 2 3 5
      Same as above, but uses workspace 5 as the holding area.

NOTES:
  - Floating window positions and sizes are preserved
  - Tiled windows retain order but may not replicate original layout
  - Use with Hyprland only (requires hyprctl + jq)
"
  exit 0
fi

FROM_WS=$1
TO_WS=$2
HOLDING_WS=${3:-99} # Default holding workspace is 99 if not specified

if [[ -z "$FROM_WS" || -z "$TO_WS" ]]; then
  echo "Usage: move_workspace_windows_safe.sh <from_ws_id> <to_ws_id> [holding_ws_id]"
  exit 1
fi

echo "Checking if workspace $TO_WS is occupied..."

hyprctl clients -j | jq -c ".[] | select(.workspace.id == $TO_WS)" | while read -r existing; do
  addr=$(echo "$existing" | jq -r '.address')
  echo "Moving existing window ($addr) to holding workspace $HOLDING_WS..."
  hyprctl dispatch movetoworkspace "$HOLDING_WS",address:$addr
done

echo "Moving windows from $FROM_WS → $TO_WS..."

hyprctl clients -j | jq -c ".[] | select(.workspace.id == $FROM_WS)" | while read -r win; do
  addr=$(echo "$win" | jq -r '.address')
  floating=$(echo "$win" | jq -r '.floating')

  hyprctl dispatch movetoworkspace "$TO_WS",address:$addr

  if [[ "$floating" == "true" ]]; then
    x=$(echo "$win" | jq -r '.at[0]')
    y=$(echo "$win" | jq -r '.at[1]')
    w=$(echo "$win" | jq -r '.size[0]')
    h=$(echo "$win" | jq -r '.size[1]')
    hyprctl dispatch movewindowpixel exact "$x" "$y",address:$addr
    hyprctl dispatch resizewindowpixel exact "$w" "$h",address:$addr
  fi
done

echo "✅ Done."
