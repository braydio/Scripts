#!/bin/bash

# === CONFIG ===
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
FILENAME_PREFIX="ss"
DEFAULT_MODE="region"
DEFAULT_DELAY=0

# === SETUP ===
mkdir -p "$SCREENSHOT_DIR"
cd "$SCREENSHOT_DIR" || exit 1

# === FUNCTIONS ===
get_next_filename() {
  local index=1
  while [[ -e "${FILENAME_PREFIX}_$(printf '%03d' $index).png" ]]; do
    ((index++))
  done
  printf "%s_%03d.png" "$FILENAME_PREFIX" "$index"
}

take_screenshot() {
  local mode="$1"
  local delay="$2"
  local output_file
  output_file=$(get_next_filename)

  echo "📸 Capturing in $delay seconds... Mode: $mode → $output_file"
  sleep "$delay"
  hyprshot -m "$mode" -o "$output_file"
  echo "✅ Saved to $SCREENSHOT_DIR/$output_file"
}

copy_to_clipboard() {
  echo "📋 Copying region to clipboard..."
  hyprshot -m region --stdout | xclip -selection clipboard -t image/png
  echo "✅ Copied to clipboard"
}

# === ARGUMENT PARSING ===
MODE="$DEFAULT_MODE"
DELAY="$DEFAULT_DELAY"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --delay | -d)
    DELAY="$2"
    shift
    ;;
  --mode | -m)
    MODE="$2"
    shift
    ;;
  --clipboard | -cl)
    copy_to_clipboard
    exit 0
    ;;
  *)
    echo "❌ Unknown option: $1"
    exit 1
    ;;
  esac
  shift
done

# === RUN ===
take_screenshot "$MODE" "$DELAY"
