#!/bin/bash

WATCH_DIR="/mnt/netstorage/Media"
LOG="/mnt/netstorage/Media/bad_files.log"
mkdir -p "$(dirname "$LOG")"
>"$LOG"

find "$WATCH_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | while read -r FILE; do
  if ! ffprobe -v error "$FILE" >/dev/null 2>&1; then
    echo "[CORRUPT] $FILE" | tee -a "$LOG"
    # Uncomment to auto-remove
    rm "$FILE"
  fi
done
