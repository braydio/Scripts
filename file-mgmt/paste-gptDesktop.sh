
#!/bin/bash
# Script to paste clipboard contents into ChatGPT's textarea with options for a file and a message

# Function to display usage
usage() {
  echo "Usage: $0 [-f file] [-m message] [--prepend | --append]"
  echo "  -f file     Specify a file whose contents will be pasted."
  echo "  -m message  Specify a message to prepend or append to the file contents."
  echo "  --prepend   Prepend the message to the file contents (default if both options are omitted)."
  echo "  --append    Append the message to the file contents."
  exit 1
}

# Default values
FILE=""
MESSAGE=""
MODE="prepend"

# Parse arguments
while [[ "$1" != "" ]]; do
  case $1 in
    -f ) shift
         FILE=$1
         ;;
    -m ) shift
         MESSAGE=$1
         ;;
    --prepend )
         MODE="prepend"
         ;;
    --append )
         MODE="append"
         ;;
    * ) usage
         ;;
  esac
  shift
done

# Validate inputs
if [[ -z "$FILE" && -z "$MESSAGE" ]]; then
  echo "Error: You must specify a file (-f) or a message (-m)."
  usage
fi

if [[ -n "$FILE" && ! -f "$FILE" ]]; then
  echo "Error: File '$FILE' does not exist."
  exit 1
fi

# Prepare clipboard content
FILE_CONTENT=""
if [[ -n "$FILE" ]]; then
  FILE_CONTENT=$(cat "$FILE")
fi

if [[ "$MODE" == "prepend" ]]; then
  CLIPBOARD_CONTENT="$MESSAGE\n$FILE_CONTENT"
elif [[ "$MODE" == "append" ]]; then
  CLIPBOARD_CONTENT="$FILE_CONTENT\n$MESSAGE"
else
  CLIPBOARD_CONTENT="$FILE_CONTENT"
fi

# Copy the combined content to the clipboard
echo -n "$CLIPBOARD_CONTENT" | wl-copy

# Focus the ChatGPT desktop app
hyprctl dispatch focuswindow "class:chat-gpt"

# Wait for the window to focus
sleep 0.2

# Type `/` to activate the text box
wtype "/"
sleep 0.1  # Small delay to ensure the input activates

# Escape special characters for wtype
CLIPBOARD_CONTENT_ESCAPED=$(echo "$CLIPBOARD_CONTENT" | sed 's/"/\\"/g')

# Type the clipboard content directly
wtype "$CLIPBOARD_CONTENT_ESCAPED"

# Calculate delay based on content length
CONTENT_LENGTH=${#CLIPBOARD_CONTENT}
DELAY=$(echo "scale=2; $CONTENT_LENGTH * 0.05" | bc)  # 50ms per character

# Wait for the paste operation to complete
sleep "$DELAY"

# Press Enter to send the message
wtype --key enter

echo "Clipboard contents pasted into ChatGPT."

