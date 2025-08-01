#!/bin/bash

# Define the default screenshot directory
SCREENSHOT_DIR=~/Pictures/screenshots
mkdir -p "$SCREENSHOT_DIR"

# Generate the date part for filenames
DATE_PART=$(date +%m%d)

# Function to get the next count for today's snaps
get_snap_count() {
  local snap_count
  snap_count=$(ls "${SCREENSHOT_DIR}/snap.${DATE_PART}.*.jpg" 2>/dev/null | wc -l)
  echo $((snap_count + 1))
}

# Function to open a specific snapshot
open_snap() {
  local target_date="$1"
  local snap_number="${2:-1}"
  local target_file="${SCREENSHOT_DIR}/snap.${target_date}.${snap_number}.jpg"

  if [[ -f "$target_file" ]]; then
    xdg-open "$target_file"
    echo "Opened $target_file"
  else
    echo "Error: File $target_file does not exist."
    exit 1
  fi
}

# Detect if the last argument is -d or --dir, so we can cd later
DO_CD=false
if [[ "${@: -1}" == "-d" || "${@: -1}" == "--dir" ]]; then
  DO_CD=true
  # Strip the last argument (the -d/--dir) so it doesn't interfere with case matching
  set -- "${@:1:$(($# - 1))}"
fi

# Parse the (now possibly stripped) arguments
case "$1" in
-r | --region)
  SNAP_COUNT=$(get_snap_count)
  OUTPUT_FILE="${SCREENSHOT_DIR}/snap.${DATE_PART}.${SNAP_COUNT}.jpg"
  hyprshot -m region -o "$OUTPUT_FILE"
  echo "Saved region screenshot to $OUTPUT_FILE"
  ;;
-s | --screen)
  SNAP_COUNT=$(get_snap_count)
  OUTPUT_FILE="${SCREENSHOT_DIR}/snap.${DATE_PART}.${SNAP_COUNT}.jpg"
  hyprshot -m screen -o "$OUTPUT_FILE"
  echo "Saved screen screenshot to $OUTPUT_FILE"
  ;;
-cl | --clipboard)
  hyprshot -m region --stdout | xclip -selection clipboard -t image/png
  echo "Region screenshot copied to clipboard"
  ;;
-o | --open)
  if [[ -z "$2" ]]; then
    echo "Error: Missing date argument for open."
    echo "Usage: snap -o <date> [snapshot_number]"
    exit 1
  fi
  open_snap "$2" "$3"
  ;;
*)
  echo "Usage: snap [options]"
  echo "  -r, --region             Take a region screenshot"
  echo "  -s, --screen             Take a full screen screenshot"
  echo "  -cl, --clipboard         Copy a region screenshot to clipboard"
  echo "  -o, --open <date> [#]    Open the specified snapshot (e.g. snap -o 0117 1)"
  echo "  -d, --dir                After taking/opening the screenshot, cd into \$SCREENSHOT_DIR"
  exit 1
  ;;
esac

# To activate ;cd into Screenshot Dir, "eval ./screenshot.sh -r -d"
if [ "$DO_CD" = true ]; then
  echo "cd \"$SCREENSHOT_DIR\""
fi
