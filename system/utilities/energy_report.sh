#!/bin/bash

declare -A bulbs=(
  ["study"]="192.168.1.242"
  ["bedroom"]="192.168.1.241"
  ["living1"]="192.168.1.235"
  ["living2"]="192.168.1.219"
)

# Define your estimated cost per kWh
cost_per_kwh=0.15

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <study|bedroom|living1|living2> <command> [args]"
  exit 1
fi

bulb="${bulbs[$1]}"
shift

if [[ -z "$bulb" ]]; then
  echo "Unknown bulb name"
  exit 1
fi

# Only process if the command is 'state'
if [[ "$2" != "state" ]]; then
  kasa --host "$bulb" "$@"
  exit 0
fi

# Capture the state output
state_output=$(kasa --host "$bulb" state)

# Parse the required values
# Extract consumption_today in kWh
consumption_today=$(echo "$state_output" | awk -F": " '/Today\'s consumption \(consumption_today\):/ {gsub(/[^\d\.]/,"",$2); print $2}')

# Extract consumption_this_month in kWh
consumption_month=$(echo "$state_output" | awk -F": " '/This month\'s consumption \(consumption_this_month\):/ {gsub(/[^\d\.]/,"",$2); print $2}')

# Calculate costs
cost_today=$(echo "$consumption_today * $cost_per_kwh" | bc)
cost_month=$(echo "$consumption_month * $cost_per_kwh" | bc)

# Print Summary Stats
echo "=== Usage Summary for $1 ==="
printf "Today's consumption: %.3f kWh, Cost: $%.2f\n" "$consumption_today" "$cost_today"
printf "This month's consumption: %.3f kWh, Cost: $%.2f\n" "$consumption_month" "$cost_month"

# Optional: Print raw data for reference
echo
echo "Raw consumption_today: $consumption_today kWh"
echo "Raw consumption_this_month: $consumption_month kWh"
echo "Estimated cost today: $$.2f"
echo "Estimated cost this month: $$.2f"
