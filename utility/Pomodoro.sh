#!/bin/bash

# Default values
default_work=10
default_break=2
minecraft_music="$HOME/Music/MinecraftMusic.mp3"
ipc_socket="/tmp/mpv-socket"

# Usage info
usage() {
  echo "Usage: timer [work_minutes] [break_minutes] [message]"
  echo "Defaults: work=${default_work}m, break=${default_break}m, no message"
  exit 1
}

# Parse arguments
work_duration=${1:-$default_work}
break_duration=${2:-$default_break}
custom_message=${3:-""}

# Validate numeric inputs
if ! [[ "$work_duration" =~ ^[0-9]+$ ]] || ! [[ "$break_duration" =~ ^[0-9]+$ ]]; then
  echo "Error: durations must be integers (minutes)."
  usage
fi

# Music controls
play_music() {
  if pgrep -x "mpv" >/dev/null; then
    playerctl play
  else
    mpv --no-video "$minecraft_music" --loop-file=inf --input-ipc-server="$ipc_socket" >/dev/null 2>&1 &
  fi
}

pause_music() {
  if pgrep -x "mpv" >/dev/null; then
    echo '{ "command": ["set_property", "pause", true] }' | socat - "$ipc_socket"
  fi
}

# Main loop
while true; do
  notify-send -t 5000 "Pomodoro Timer" "Work for $work_duration minutes. $custom_message"
  play_music
  sleep "$((work_duration * 60))"

  pause_music
  notify-send "Pomodoro Timer" "Work done! Break for $break_duration minutes."

  sleep "$((break_duration * 60))"
  notify-send "Pomodoro Timer" "Break over. Time to focus again!"
done
