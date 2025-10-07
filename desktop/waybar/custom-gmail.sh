#!/bin/bash

# Sync emails
mbsync -a >/dev/null 2>&1

# Directory containing unread emails (maildir "new" folder)
EMAIL_DIR=~/.mail/Gmail/Inbox/new/

# Count unread emails in the main folder
UNREAD_COUNT=$(find "$EMAIL_DIR" -type f 2>/dev/null | wc -l)

# File to store the previous unread count
PREV_COUNT_FILE="/tmp/All_unread_count"

# Read the previous unread count (default to 0 if file doesn't exist)
if [[ -f "$PREV_COUNT_FILE" ]]; then
  PREV_COUNT=$(cat "$PREV_COUNT_FILE")
else
  PREV_COUNT=0
fi

# Helper function to truncate a string if it exceeds a maximum length.
truncate_string() {
  local str="$1"
  local max_len="$2"
  if [ ${#str} -gt $max_len ]; then
    echo "${str:0:$((max_len - 3))}..."
  else
    echo "$str"
  fi
}

# Only send a notification if there are new emails since the last check.
if [[ $UNREAD_COUNT -gt $PREV_COUNT ]]; then
  NEW_EMAILS=$((UNREAD_COUNT - PREV_COUNT))

  # Build a summary of the newest emails (limit to 5)
  notification_body=""
  # List files sorted by modification time (newest first)
  mapfile -t email_files < <(ls -t "$EMAIL_DIR" 2>/dev/null)
  num_to_show=5
  count=0

  for file in "${email_files[@]}"; do
    # Stop after processing the desired number
    if ((count >= num_to_show)); then
      break
    fi
    full_path="$EMAIL_DIR/$file"
    # Extract the sender line (assumes header starts with "From:")
    sender=$(grep -m 1 -i "^From:" "$full_path" | sed 's/^[Ff]rom:[[:space:]]*//')
    # Extract the subject line (assumes header starts with "Subject:")
    subject=$(grep -m 1 -i "^Subject:" "$full_path" | sed 's/^[Ss]ubject:[[:space:]]*//')
    # Provide defaults if fields are empty
    sender=${sender:-"Unknown Sender"}
    subject=${subject:-"(no subject)"}
    # Truncate sender and subject if they are too long
    sender=$(truncate_string "$sender" 40)
    subject=$(truncate_string "$subject" 70)
    notification_body+="$sender - $subject\n"
    ((count++))
  done

  # Prepend a summary line
  header="You've got $NEW_EMAILS new email(s):"
  final_msg="$header\n$notification_body"

  notify-send -t 20000 -u normal -i "mail-mark-unread-symbolic" "New Mail" "$final_msg"
fi

# Save the current unread count to the file
echo $UNREAD_COUNT >"$PREV_COUNT_FILE"

# Output for Waybar
echo -e "{\"text\": \"✉ $UNREAD_COUNT\", \"tooltip\": \"All: $UNREAD_COUNT unread\"}"
