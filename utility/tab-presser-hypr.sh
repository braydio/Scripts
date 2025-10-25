#!/bin/bash

LOGFILE="$HOME/vnc_input_logger.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

log "Now logging Tab and Space via hyprctl events (Ctrl+C to stop)"

hyprctl -j events | jq -r '
  select(.type == "key_press") |
  if .keycode == 15 then
    "[" + (now | strftime("%Y-%m-%d %H:%M:%S")) + "] Tab pressed"
  elif .keycode == 57 then
    "[" + (now | strftime("%Y-%m-%d %H:%M:%S")) + "] Space pressed"
  else empty end
' | tee -a "$LOGFILE"
