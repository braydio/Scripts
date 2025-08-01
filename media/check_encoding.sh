#!/bin/bash

WATCH_DIRS=("/mnt/netstorage/Media/Downloads" "/mnt/netstorage/Media/TV" "/mnt/netstorage/Media/Movies" "/mnt/netstorage/Media/Music")
NOTIFY_URL="http://piw0.local:5000/notify" # Replace with actual IP/hostname and port of your PiW0

for DIR in "${WATCH_DIRS[@]}"; do
  find "$DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \) | while read -r FILE; do
    VIDEO_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$FILE")
    AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=nw=1:nk=1 "$FILE")

    if [[ "$VIDEO_CODEC" =~ ^(hevc|vp9)$ || "$AUDIO_CODEC" =~ ^(eac3|dts)$ ]]; then
      curl -X POST -H "Content-Type: application/json" -d "{\"file\":\"$FILE\",\"video\":\"$VIDEO_CODEC\",\"audio\":\"$AUDIO_CODEC\"}" "$NOTIFY_URL"
    fi
  done
done
