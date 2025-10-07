#!/bin/bash

LOG_FILE="$HOME/Documents/hydration_log.json"

# Ensure file exists and is a valid JSON array
if [ ! -f "$LOG_FILE" ]; then
  echo "[]" >"$LOG_FILE"
fi

function prompt_and_log() {
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  zenity --question --text="Did you drink water?" --ok-label="Yes" --cancel-label="No"
  local water=$?
  [[ "$water" == "0" ]] && water="true" || water="false"

  zenity --question --text="Did you take Adderall since last check?" --ok-label="Yes" --cancel-label="No"
  local adderall=$?
  [[ "$adderall" == "0" ]] && adderall="true" || adderall="false"

  local project
  project=$(zenity --entry --title="Current Focus" --text="What are you working on?")
  project=$(echo "$project" | jq -Rsa .) # safely JSON-encode string

  local tmpfile
  tmpfile=$(mktemp)

  # Safely append entry
  if jq ". += [{\"timestamp\":\"$timestamp\",\"drank_water\":$water,\"took_adderall\":$adderall,\"working_on\":$project}]" "$LOG_FILE" >"$tmpfile"; then
    mv "$tmpfile" "$LOG_FILE"
  else
    echo "Failed to update log file" >&2
    rm "$tmpfile"
  fi
}

# Run in the same shell, not kitty subshell
while true; do
  prompt_and_log
  sleep 3600
done
