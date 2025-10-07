#!/usr/bin/env bash
#
# A feature-rich Bash script timer that lets you set hours, minutes, and seconds
# via flags. It can display remaining time, optionally loop, print a custom
# message, and send a desktop notification (if notify-send is available).
#
# Usage examples:
#   ./timer.sh -m 5                       # 5-minute countdown
#   ./timer.sh -m 2 -s 30                 # 2 minutes 30 seconds countdown
#   ./timer.sh -h 1 -m 10 -s 5            # 1 hour, 10 minutes, 5 seconds
#   ./timer.sh -m 25 -p "Take a short break!" -n  # 25 min countdown w/ message & notification
#   ./timer.sh -m 25 -l 4 -p "Pomodoro"   # 4 loops of 25-min countdown with message
#
# Options:
#   -H, --hours <H>       : Set hours
#   -m, --minutes <M>     : Set minutes
#   -s, --seconds <S>     : Set seconds
#   -l, --loop <LOOP>     : Repeat countdown N times
#   -p, --prompt <MSG>    : Custom text to display at the end
#   -n, --notify          : Use 'notify-send' (if available) to send a desktop notification at the end
#   -h, --help            : Show this help message
#

# ------------------ Default values ------------------
HOURS=0
MINUTES=0
SECONDS=0
LOOP=1
PROMPT=""
USE_NOTIFY=false

# ------------------ Helper Functions ------------------

# Print usage instructions.
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -H, --hours <H>       Set hours (default: 0)
  -m, --minutes <M>     Set minutes (default: 0)
  -s, --seconds <S>     Set seconds (default: 0)
  -l, --loop <LOOP>     Repeat the countdown N times (default: 1)
  -p, --prompt <MSG>    Custom message displayed after countdown
  -n, --notify          Use 'notify-send' (if available) for desktop notification
  -h, --help            Show this help and exit

Examples:
  $(basename "$0") -m 5
  $(basename "$0") -m 2 -s 30
  $(basename "$0") -m 25 -p "Take a short break!"
  $(basename "$0") -m 25 -l 4 -p "Pomodoro Round" -n
EOF
}

# Convert hours, minutes, seconds -> total seconds
convert_to_seconds() {
  local h="$1"
  local m="$2"
  local s="$3"
  echo $((h * 3600 + m * 60 + s))
}

# Show a simple countdown display (HH:MM:SS) updated every second
countdown() {
  local total="$1"
  while [ $total -gt 0 ]; do
    # Convert total seconds to HH:MM:SS
    local h=$((total / 3600))
    local m=$(((total % 3600) / 60))
    local s=$((total % 60))

    printf "\rTime Left: %02d:%02d:%02d " "$h" "$m" "$s"

    sleep 1
    total=$((total - 1))
  done
  printf "\n"
}

# Send a desktop notification if notify-send is available and user requested it
send_notification() {
  local msg="$1"
  if $USE_NOTIFY && command -v notify-send >/dev/null 2>&1; then
    notify-send "Timer Finished" "$msg"
  fi
}

# ------------------ Parse Arguments ------------------
# We use a while-loop + case to handle both short and long options.
while [[ $# -gt 0 ]]; do
  case "$1" in
  -H | --hours)
    HOURS="$2"
    shift 2
    ;;
  -m | --minutes)
    MINUTES="$2"
    shift 2
    ;;
  -s | --seconds)
    SECONDS="$2"
    shift 2
    ;;
  -l | --loop)
    LOOP="$2"
    shift 2
    ;;
  -p | --prompt)
    PROMPT="$2"
    shift 2
    ;;
  -n | --notify)
    USE_NOTIFY=true
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

# ------------------ Main Script Logic ------------------

# Convert total time to seconds
TOTAL_SECONDS=$(convert_to_seconds "$HOURS" "$MINUTES" "$SECONDS")

# If no time was given, show help and exit
if [ "$TOTAL_SECONDS" -le 0 ]; then
  echo "Error: Please provide a valid duration."
  usage
  exit 1
fi

# Loop the countdown the number of times requested
for ((i = 1; i <= LOOP; i++)); do
  echo "Starting countdown #$i (of $LOOP) for $HOURS hour(s), $MINUTES minute(s), $SECONDS second(s)."
  countdown "$TOTAL_SECONDS"

  # Print the final prompt if provided
  if [ -n "$PROMPT" ]; then
    echo "[$(date +'%T')] $PROMPT"
  else
    echo "[$(date +'%T')] Timer finished!"
  fi

  # Optionally beep (if terminal bell is desired)
  # echo -en "\a"

  # Optionally send a desktop notification
  send_notification "${PROMPT:-"Timer Finished"}"

  # If there's more loops, you might want a short pause before the next loop
  # sleep 5  # Uncomment/adjust for break time between loops
done
