#!/bin/bash

# CONFIGURATION
WATCH_DIR="/mnt/netstorage/Media"
LOGFILE="/mnt/netstorage/Media/healthcheck_badfiles.log"
CORRUPT_DIR="/mnt/netstorage/Media/Corrupt"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1326653489711153326/u2Ez2nqOFYvyEq1xSDntw16B7VBjDWbrDdErnYtV61S_J8l5NlHUFZ6tVvxK4d-L1vuy"
SONARR_URL=http://192.168.1.85:8989
RADARR_URL=http://192.168.1.85:7878
API_KEY_RADARR=21d44b12bf484693a8fea99e72b0b6bc
API_KEY_SONARR=a73738c180e14b3787e54bcfb6682566

# Create dirs
mkdir -p "$(dirname "$LOGFILE")" "$CORRUPT_DIR"
>"$LOGFILE"

echo "=== Media Health Check: $(date) ===" >>"$LOGFILE"

# Function to notify Discord
notify_discord() {
  curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$1\"}" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1
}

# Function to trigger Sonarr/Radarr rescan
trigger_rescan() {
  curl -s -X POST "$SONARR_URL/api/command" \
    -H "X-Api-Key: $API_KEY_SONARR" \
    -H "Content-Type: application/json" \
    -d '{"name": "RescanSeries"}' >/dev/null

  curl -s -X POST "$RADARR_URL/api/command" \
    -H "X-Api-Key: $API_KEY_RADARR" \
    -H "Content-Type: application/json" \
    -d '{"name": "RescanMovie"}' >/dev/null
}

# Scan for corrupt files
find "$WATCH_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.webm" \) | while read -r FILE; do
  if ! ffprobe -v error "$FILE" >/dev/null 2>&1; then
    echo "[CORRUPT] $FILE" >>"$LOGFILE"

    # Send to Discord
    notify_discord ":x: Corrupt media file detected and removed:\n$FILE"

    # Move to quarantine folder (optional)
    mv "$FILE" "$CORRUPT_DIR/"

    # Trigger Sonarr/Radarr rescan
    trigger_rescan
  fi
done
