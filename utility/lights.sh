#!/bin/bash

declare -A bulbs=(
  ["study"]="192.168.1.99"
  ["bedroom"]="192.168.1.241"
  ["living1"]="192.168.1.235"
  ["living2"]="192.168.1.219"
)

# Fixed color mapping (hue values 0–360)
declare -A colors=(
  # Reds
  ["red"]="0"
  ["orange"]="30"
  ["amber"]="45"

  # Yellows & Greens
  ["yellow"]="60"
  ["lime"]="90"
  ["green"]="120"

  # Cyans & Blues
  ["aqua"]="160"
  ["cyan"]="180"
  ["sky"]="200"
  ["blue"]="240"
  ["indigo"]="260"

  # Purples & Magentas
  ["violet"]="280"
  ["purple"]="300"
  ["magenta"]="320"
  ["pink"]="340"
)

# Define your estimated cost per kWh
cost_per_kwh=0.15

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <study|bedroom|living1|living2> <command> [args]"
  echo
  echo "Commands:"
  echo "  state                 Show power usage and estimated costs"
  echo "  color <name>          Set bulb to a named color (${!colors[@]})"
  echo "  <other kasa command>  Pass through to kasa CLI"
  exit 1
fi

bulb="${bulbs[$1]}"
shift

if [[ -z "$bulb" ]]; then
  echo "Unknown bulb name"
  exit 1
fi

# Handle color command
if [[ "$1" == "color" ]]; then
  if [[ -z "$2" ]]; then
    echo "Please provide a color name. Available: ${!colors[@]}"
    exit 1
  fi

  color_name="$2"
  hue="${colors[$color_name]}"

  if [[ -z "$hue" ]]; then
    echo "Unknown color '$color_name'. Available: ${!colors[@]}"
    exit 1
  fi

  kasa --host "$bulb" hsv --hue "$hue" --saturation 100 --value 100
  exit 0
fi

# Only process if the command is 'state'
if [[ "$1" != "state" ]]; then
  kasa --host "$bulb" "$@"
  exit 0
fi

# Capture the state output
state_output=$(kasa --host "$bulb" state)

# Parse the required values
# Extract consumption_today in kWh

# Extract consumption_this_month in kWh
consumption_month=$(echo "$state_output" | awk -F": " '/This month\'s consumption \(consumption_this_month\):/ {gsub(/[^\d\.]/,"",$2); print $2}')

# Calculate costs
cost_today=$(echo "$consumption_today * $cost_per_kwh" | bc)
cost_month=$(echo "$consumption_month * $cost_per_kwh" | bc)

# Print Summary Stats
echo "=== Usage Summary for $1 ==="
printf "Today's consumption: %.3f kWh, Cost: \$%.2f\n" "$consumption_today" "$cost_today"
printf "This month's consumption: %.3f kWh, Cost: \$%.2f\n" "$consumption_month" "$cost_month"

# Optional: Print raw data for reference
echo
echo "Raw consumption_today: $consumption_today kWh"
echo "Raw consumption_this_month: $consumption_month kWh"
