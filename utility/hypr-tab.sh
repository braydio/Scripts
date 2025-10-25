#!/bin/bash
# hypr-input-logger.sh

LOGFILE="$HOME/vnc_input_logger.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

TAB_COUNT=0
SPACE_COUNT=0

log "Now logging Tab and Space via hyprctl events (Ctrl+C to stop)"

hyprctl events | while read -r line; do
  ts="[$(date '+%F %T')]"
  if [[ "$line" =~ ^key.*pressed[[:space:]]+15 ]]; then
    ((TAB_COUNT++))
    log "$ts Tab pressed (count: $TAB_COUNT)"
  elif [[ "$line" =~ ^key.*pressed[[:space:]]+57 ]]; then
    ((SPACE_COUNT++))
    log "$ts Space pressed (count: $SPACE_COUNT)"
  fi
done
