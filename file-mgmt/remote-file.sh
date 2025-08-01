#!/bin/bash

# Server list: IP:Name:Password:User
SERVERS=(
  "192.168.1.198:Raspberry Pi 4:03231997:braydenchaffee"
  "192.168.1.78:Pi Zero W:03231997:braydenchaffee"
  "192.168.1.225:MacBook Pro:braydenchaffee"
  "192.168.1.228:archlinux:0323:braydenchaffee"
)

DEFAULT_SERVER_INDEX=4

# Flags
ACTION=""
SRC_PATH=""
DST_PATH=""
SERVER_SELECTION=""
USE_FZF=false
NO_OVERWRITE=false
CHECK_SYNC=false
CLIP_REMOTE=false

# Help
usage() {
  echo "Usage:"
  echo "  cppi send|get <path> [-s index|match] [--no-overwrite] [--fzf]"
  echo "  cppi --ssh-copy <remote_path> [-s index|match|--fzf]"
  echo "  cppi check-sync <remote_path> [-s index|match|--fzf]"
  exit 1
}

# Argument parsing
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  get | send)
    ACTION="$1"
    ;;
  -src | --source)
    SRC_PATH="$2"
    shift
    ;;
  -dst | --destination)
    DST_PATH="$2"
    shift
    ;;
  -s | --server)
    SERVER_SELECTION="$2"
    shift
    ;;
  --fzf)
    USE_FZF=true
    ;;
  --no-overwrite)
    NO_OVERWRITE=true
    ;;
  --ssh-copy)
    ACTION="ssh-copy"
    SRC_PATH="$2"
    shift
    ;;
  check-sync)
    CHECK_SYNC=true
    ACTION="get"
    SRC_PATH="$2"
    DST_PATH="./$(basename "$SRC_PATH")"
    shift
    ;;
  -*)
    echo "Unknown flag: $1"
    usage
    ;;
  *)
    POSITIONAL+=("$1")
    ;;
  esac
  shift
done

# Restore positional
set -- "${POSITIONAL[@]}"

# Set SRC_PATH if not already from flag
if [[ -z "$SRC_PATH" && -n "$1" && "$ACTION" != "ssh-copy" && "$ACTION" != "check-sync" ]]; then
  SRC_PATH="$1"
  DST_PATH="${DST_PATH:-$1}"
fi

# Validate required inputs
[[ -z "$ACTION" || -z "$SRC_PATH" ]] && usage

# Server selection logic
if $USE_FZF && command -v fzf >/dev/null; then
  SELECTED_SERVER=$(printf "%s\n" "${SERVERS[@]}" | fzf --prompt="Select server: ")
elif [[ -n "$SERVER_SELECTION" ]]; then
  if [[ "$SERVER_SELECTION" =~ ^[0-9]+$ ]]; then
    SELECTED_SERVER="${SERVERS[$((SERVER_SELECTION - 1))]}"
  else
    SELECTED_SERVER=$(printf "%s\n" "${SERVERS[@]}" | grep -i "$SERVER_SELECTION")
  fi
else
  echo "Select the server:"
  select SERVER in "${SERVERS[@]}"; do
    [[ -n "$SERVER" ]] && SELECTED_SERVER="$SERVER" && break
    echo "Invalid selection."
  done
fi

# Parse selected server
IFS=":" read -r SERVER_IP NAME PASSWORD USER <<<"$SELECTED_SERVER"
echo "Selected server: $NAME ($SERVER_IP)"

# ========== ACTION HANDLING ==========

if [[ "$ACTION" == "get" ]]; then
  [[ -z "$DST_PATH" ]] && DST_PATH="./$(basename "$SRC_PATH")"
  if [[ "$NO_OVERWRITE" == true && -f "$DST_PATH" ]]; then
    echo "File '$DST_PATH' already exists. Skipping due to --no-overwrite."
    exit 0
  fi
  echo "Fetching '$SRC_PATH' from $NAME..."
  sshpass -p "$PASSWORD" scp "$USER@$SERVER_IP:$SRC_PATH" "$DST_PATH"

elif [[ "$ACTION" == "send" ]]; then
  [[ -z "$DST_PATH" ]] && DST_PATH="$SRC_PATH"
  echo "Sending '$SRC_PATH' to $NAME..."
  sshpass -p "$PASSWORD" scp "$SRC_PATH" "$USER@$SERVER_IP:$DST_PATH"

elif [[ "$ACTION" == "ssh-copy" ]]; then
  echo "Copying contents of '$SRC_PATH' from $NAME to clipboard..."
  CONTENT=$(sshpass -p "$PASSWORD" ssh "$USER@$SERVER_IP" "cat '$SRC_PATH'")
  if command -v wl-copy >/dev/null; then
    echo "$CONTENT" | wl-copy
    echo "[+] Copied to clipboard via wl-copy"
  elif command -v xclip >/dev/null; then
    echo "$CONTENT" | xclip -selection clipboard
    echo "[+] Copied to clipboard via xclip"
  else
    echo "[-] No clipboard utility found (needs wl-copy or xclip)"
    exit 1
  fi

elif [[ "$CHECK_SYNC" == true ]]; then
  echo "Opening remote file in nvim on $NAME..."
  sshpass -p "$PASSWORD" ssh -t "$USER@$SERVER_IP" "nvim '$SRC_PATH'"
  read -p "Sync this file to local '$DST_PATH'? [y/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    sshpass -p "$PASSWORD" scp "$USER@$SERVER_IP:$SRC_PATH" "$DST_PATH"
    echo "[✓] File synced to $DST_PATH"
  else
    echo "[×] Sync cancelled."
  fi

else
  echo "Invalid or unsupported action: $ACTION"
  usage
fi
