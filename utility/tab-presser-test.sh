#!/bin/bash
# input-logger.sh

LOGFILE="$HOME/vnc_input_logger.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

RAW_X=1158
RAW_Y=475
CLICK_X=$((RAW_X / 2))
CLICK_Y=$((RAW_Y / 2))

# ==============================
# Focus and activate TigerVNC
# ==============================
log "Focusing TigerVNC window"
hyprctl dispatch focuswindow "class:^Vncviewer$"
sleep 0.3

log "Cursor before move: $(hyprctl cursorpos)"
ydotool mousemove --absolute -x "$CLICK_X" -y "$CLICK_Y"
ydotool click 0:1
ydotool click 0:0
sleep 0.3
log "Cursor after move: $(hyprctl cursorpos)"

# ==============================
# Log keyboard events with counters
# ==============================
TAB_COUNT=0
SPACE_COUNT=0

log "Now logging Tab (15) and Space (57) (Ctrl+C to stop)"

libinput debug-events |
  awk -v logfile="$LOGFILE" '
    BEGIN { tab=0; space=0 }
    /event2/ && /KEYBOARD_KEY/ {
      ts = strftime("[%Y-%m-%d %H:%M:%S]")
      if ($4 == "+15" && $5 == "pressed") {
        tab++
        print ts, $0, "=> Tab (count:", tab, ")" | "tee -a " logfile
      }
      else if ($4 == "+57" && $5 == "pressed") {
        space++
        print ts, $0, "=> Space (count:", space, ")" | "tee -a " logfile
      }
    }
  '
