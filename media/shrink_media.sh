#!/bin/bash

# Set your media directories
SOURCE_DIRS=(
  "/mnt/netstorage/Media/TV"
  "/mnt/netstorage/Media/Movies"
  "/mnt/netstorage/Media/Music"
)

DEST_BASE="/mnt/netstorage/Media/converted"
MIN_SIZE_GB=20
LOG_FILE="/mnt/netstorage/Media/converted_log.txt"

mkdir -p "$DEST_BASE"

for DIR in "${SOURCE_DIRS[@]}"; do
  echo "[SCAN] Checking directory: $DIR" | tee -a "$LOG_FILE"

  find "$DIR" -type f -iname '*.mkv' | while read -r f; do
    size_gb=$(du -BG "$f" | cut -f1 | sed 's/G//')

    # Skip if file is too small
    if [ "$size_gb" -lt "$MIN_SIZE_GB" ]; then
      continue
    fi

    # Skip if video is already H.265
    codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
      -of default=nokey=1:noprint_wrappers=1 "$f")

    if [[ "$codec" == "hevc" || "$codec" == "h265" ]]; then
      echo "[SKIP] Already H.265: $f ($size_gb GB)" | tee -a "$LOG_FILE"
      continue
    fi

    base=$(basename "$f")
    relative="${f#$DIR/}"
    output="$DEST_BASE/${relative%.mkv}_x265.mkv"

    mkdir -p "$(dirname "$output")"

    echo "[ENCODE] $base ($size_gb GB) → $output" | tee -a "$LOG_FILE"

    ffmpeg -i "$f" -c:v libx265 -crf 24 -c:a aac -b:a 128k "$output"

    echo "[DONE] $base re-encoded." | tee -a "$LOG_FILE"

    # Optional: delete original
    # rm "$f"
  done
done

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1339755598157185044/us4Qb1eKXC485Bduj3zf0xYivWZbQ3RCHMDQ_yoIOEXoZfCOwJ39LXwVwxl8mb7_bdVW"
curl -H "Content-Type: application/json" -X POST \
  -d "{\"content\": \"✅ Re-encoded: $base ($size_gb GB)\"}" \
  "$DISCORD_WEBHOOK_URL"
