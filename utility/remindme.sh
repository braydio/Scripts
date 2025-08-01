#!/bin/bash

REM_FILE="${HOME}/.reminders"

function add_reminder() {
  echo "📅 Add a New Reminder"

  read -p "Date (YYYY-MM-DD): " date
  read -p "Time (HH:MM, optional): " time
  read -p "Message: " message
  read -p "Repeat? (none/daily/weekly/monthly/yearly): " repeat

  # Format date
  rem_date=$(date -d "$date" +"%Y %m %d" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "❌ Invalid date."
    exit 1
  fi

  # Build repeat pattern
  repeat_str=""
  case "$repeat" in
  daily) repeat_str="*" ;;
  weekly) repeat_str="* +7" ;;
  monthly) repeat_str="* +1" ;;
  yearly) repeat_str="* +12" ;;
  esac

  # Final line
  if [ -n "$time" ]; then
    line="REM $date AT $time $repeat_str MSG $message"
  else
    line="REM $date $repeat_str MSG $message"
  fi

  echo "$line" >>"$REM_FILE"
  echo "✅ Reminder added!"
}

function show_reminders_today() {
  echo "📌 Reminders for Today:"
  remind -q "$REM_FILE"
}

function menu() {
  echo "=== 🕰️ Reminder CLI ==="
  echo "1. Add a new reminder"
  echo "2. Show today's reminders"
  echo "3. Show all upcoming reminders"
  echo "0. Exit"
  read -p "Choose: " choice

  case $choice in
  1) add_reminder ;;
  2) show_reminders_today ;;
  3) remind "$REM_FILE" ;;
  0) exit ;;
  *) echo "Invalid choice." ;;
  esac
}

# Loop menu
while true; do
  menu
  echo ""
done
