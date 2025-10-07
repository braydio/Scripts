#!/bin/bash

DOING_SECTION="Today"
SYNC_PATH="/mnt/netstorage/Files/DoingList.md" # Change to .txt if you want

sync_doing_list() {
  # Export current unfinished tasks to markdown file
  doing show "$DOING_SECTION" --not-done --markdown >"$SYNC_PATH"
}

while true; do
  ACTION=$(zenity --list --radiolist \
    --title="Doing: Task Manager" \
    --text="What would you like to do?" \
    --column="Pick" --column="Action" \
    TRUE "Add Task" \
    FALSE "View Tasks" \
    FALSE "Complete Task" \
    FALSE "Sync Now" \
    FALSE "Quit" \
    --width=350 --height=250)

  case "$ACTION" in
  "Add Task")
    TASK=$(zenity --entry --title="Add Task" --text="What do you need to do?")
    if [[ -n "$TASK" ]]; then
      doing add "$TASK" -s "$DOING_SECTION"
      zenity --info --text="Task added: $TASK"
      sync_doing_list
    fi
    ;;
  "View Tasks")
    doing show "$DOING_SECTION" --not-done --plain |
      zenity --text-info --title="Current Tasks" --width=500 --height=300
    ;;
  "Complete Task")
    TASKS=$(doing show "$DOING_SECTION" --not-done --plain)
    if [[ -z "$TASKS" ]]; then
      zenity --info --text="No tasks to complete!"
      continue
    fi
    TASK=$(echo "$TASKS" | nl -w2 -s'. ' | zenity --list --title="Complete Task" --column="Number" --column="Task" --width=600 --height=400)
    if [[ -n "$TASK" ]]; then
      NUM=$(echo "$TASK" | awk '{print $1}')
      UUID=$(doing show "$DOING_SECTION" --not-done --uuid | sed -n "${NUM}p" | awk '{print $1}')
      if [[ -n "$UUID" ]]; then
        doing done "$UUID"
        zenity --info --text="Task marked complete."
        sync_doing_list
      fi
    fi
    ;;
  "Sync Now")
    sync_doing_list
    zenity --info --text="Tasks synced to $SYNC_PATH"
    ;;
  *)
    exit 0
    ;;
  esac
done
