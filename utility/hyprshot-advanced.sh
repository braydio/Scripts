#!/bin/bash

# Default values
DELAY=0
MODE="window"
DIR="$HOME/Pictures/Screenshots"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --delay | -d)
    DELAY="$2"
    shift
    ;;
  --mode | -m)
    MODE="$2"
    shift
    ;;
  --dir)
    DIR="$2"
    shift
    ;;
  *)
    echo "❌ Unknown option: $1"
    exit 1
    ;;
  esac
  shift
done

# Validate mode
if [[ "$MODE" != "window" && "$MODE" != "output" && "$MODE" != "region" ]]; then
  echo "❌ Invalid mode: $MODE"
  echo "Valid modes: window, output, region"
  exit 1
fi

# Ensure the directory exists
mkdir -p "$DIR"

# Filename with timestamp
FILENAME="$DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# Perform delayed capture
echo "📸 Capturing in $DELAY seconds... Mode: $MODE → $FILENAME"
sleep "$DELAY"
hyprshot -m "$MODE" -o "$FILENAME"
