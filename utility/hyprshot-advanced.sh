#!/bin/bash

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
DATE=$(date '+%Y-%m-%d-%H%M%S')

# Default to region if no arg
MODE="${1:-region}"

case "$MODE" in
region)
  MODEARG="-m region"
  ;;
window)
  MODEARG="-m window"
  ;;
screen | full)
  MODEARG="-m output"
  ;;
*)
  echo "Usage: $0 [region|window|screen]"
  echo "  region - screenshot a selected region (default)"
  echo "  window - screenshot a selected window"
  echo "  screen - screenshot the whole screen"
  exit 1
  ;;
esac

FILE="$DIR/${DATE}_hyprshot.png"

# Call hyprshot with selected mode, output to file
hyprshot $MODEARG -o "$FILE"

if [ ! -f "$FILE" ]; then
  echo "Error: Screenshot not saved."
  exit 1
fi

# Copy to clipboard (Wayland or X11)
if command -v wl-copy &>/dev/null; then
  cat "$FILE" | wl-copy
  CLIPMSG="Copied to clipboard with wl-copy."
elif command -v xclip &>/dev/null; then
  xclip -selection clipboard -t image/png -i "$FILE"
  CLIPMSG="Copied to clipboard with xclip."
else
  CLIPMSG="No clipboard tool found (install wl-clipboard or xclip)."
fi

echo "Screenshot saved: $FILE"
echo "$CLIPMSG"
