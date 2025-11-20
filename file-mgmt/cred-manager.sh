#!/usr/bin/env bash
# Primary documentation: docs/cred-manager.md

set -euo pipefail

# Credentials Vault Script
SCRIPT_NAME=${0##*/}
VAULT_DIR=${VAULT_DIR:-"$HOME/Documents/Credentials"}

# Create vault directory if it doesn't exist
mkdir -p "$VAULT_DIR"

# Clipboard command detection
if command -v wl-copy >/dev/null 2>&1; then
  COPY_CMD="wl-copy"
elif command -v xclip >/dev/null 2>&1; then
  COPY_CMD="xclip -selection clipboard"
else
  COPY_CMD=""
fi

# Function to check for fzf
require_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is not installed. Please install it first."
    exit 1
  fi
}

print_usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME <command> [options]

Commands:
  add                 Add a new credential or API key entry.
  list                List all stored entries.
  view                View an entry using fzf for selection.
  copy                Copy a field from an entry to the clipboard.
  search <query>      Search for entries matching the query string.
  delete              Delete an entry after confirmation.

Alias hint: this script is often aliased as 'credman'.
USAGE
}

list_entries() {
  shopt -s nullglob
  local files=("$VAULT_DIR"/*.txt)
  shopt -u nullglob

  local file
  for file in "${files[@]}"; do
    basename -s .txt "$file"
  done
}

select_entry() {
  require_fzf

  local entries
  entries=$(list_entries)

  if [[ -z "$entries" ]]; then
    echo "No entries found in '$VAULT_DIR'." >&2
    return 1
  fi

  local prompt="${1:-Select entry: }"
  local selection
  selection=$(printf '%s\n' "$entries" | fzf --prompt="$prompt")

  if [[ -z "$selection" ]]; then
    echo "No entry selected." >&2
    return 1
  fi

  printf '%s' "$selection"
}

add_credential() {
  local entry_type name file user pass api_key client_id notes

  read -rp "Enter Entry Type (credential/api): " entry_type
  entry_type=${entry_type,,}
  read -rp "Enter Name: " name

  if [[ -z "$entry_type" || -z "$name" ]]; then
    echo "Entry type and name are required."
    exit 1
  fi

  file="$VAULT_DIR/$name.txt"

  echo "TYPE: $entry_type" >"$file"
  echo "NAME: $name" >>"$file"
  # Record creation date/time in ISO-8601 format
  echo "ADDED: $(date -Iseconds)" >>"$file"

  case "$entry_type" in
    credential)
      read -rp "Enter Username: " user
      read -rsp "Enter Password: " pass
      echo
      echo "USER: $user" >>"$file"
      echo "PASS: $pass" >>"$file"
      ;;
    api)
      read -rp "Enter API Key: " api_key
      read -rp "Enter Client ID (optional): " client_id
      echo "API_KEY: $api_key" >>"$file"
      if [[ -n "$client_id" ]]; then
        echo "CLIENT_ID: $client_id" >>"$file"
      fi
      ;;
    *)
      echo "Unknown entry type. Use 'credential' or 'api'."
      rm -f "$file"
      exit 1
      ;;
  esac

  read -rp "Enter Notes (optional): " notes
  echo "NOTES: $notes" >>"$file"

  echo "Entry '$name' saved."
}

list_credentials() {
  local entries
  entries=$(list_entries)

  if [[ -z "$entries" ]]; then
    echo "No entries found in '$VAULT_DIR'."
    return
  fi

  echo "Available entries:"
  printf '%s\n' "$entries"
}

view_credential() {
  local selected
  if ! selected=$(select_entry "Select entry to view: "); then
    return
  fi

  local file="$VAULT_DIR/$selected.txt"
  if [[ ! -f "$file" ]]; then
    echo "Entry '$selected' not found."
    return 1
  fi

  echo "--- $selected ---"
  cat "$file"
}

copy_field() {
  local selected
  if ! selected=$(select_entry "Select entry to copy from: "); then
    return
  fi

  local file="$VAULT_DIR/$selected.txt"
  if [[ ! -f "$file" ]]; then
    echo "Entry '$selected' not found."
    return 1
  fi

  local fields
  fields=$(awk -F': ' 'NF {print $1}' "$file")
  if [[ -z "$fields" ]]; then
    echo "No fields found in '$selected'."
    return 1
  fi

  local field
  field=$(printf '%s\n' "$fields" | fzf --prompt="Select field to copy: ")

  if [[ -z "$field" ]]; then
    echo "No field selected."
    return 1
  fi

  if ! grep -q "^$field:" "$file"; then
    echo "Field '$field' not found in '$selected'."
    return 1
  fi

  local value
  value=$(sed -n "s/^$field: //p" "$file" | head -n 1)

  if [[ -z "$value" ]]; then
    echo "Field '$field' is empty in '$selected'."
    return 1
  fi

  if [[ -n "$COPY_CMD" ]]; then
    printf '%s' "$value" | $COPY_CMD
    echo "$field from '$selected' copied to clipboard."
  else
    echo "No clipboard tool found. Here's the value:"
    echo "$value"
  fi
}

search_credentials() {
  local query=${1:-}

  if [[ -z "$query" ]]; then
    echo "Search requires a query string." >&2
    return 1
  fi

  local entries
  entries=$(list_entries)

  if [[ -z "$entries" ]]; then
    echo "No entries found in '$VAULT_DIR'."
    return 1
  fi

  local matches
  matches=$(printf '%s\n' "$entries" | grep -i "$query" || true)

  if [[ -z "$matches" ]]; then
    echo "No entries matched '$query'."
    return 1
  fi

  printf '%s\n' "$matches"
}

delete_credential() {
  local selected
  if ! selected=$(select_entry "Select entry to delete: "); then
    return
  fi

  local file="$VAULT_DIR/$selected.txt"
  if [[ ! -f "$file" ]]; then
    echo "Entry '$selected' not found."
    return 1
  fi

  read -rp "Are you sure you want to delete '$selected'? [y/N]: " confirmation
  if [[ "$confirmation" =~ ^[Yy]$ ]]; then
    rm -f "$file"
    echo "Entry '$selected' deleted."
  else
    echo "Deletion cancelled."
  fi
}

main() {
  local command=${1:-}

  case "$command" in
    add)
      add_credential
      ;;
    list)
      list_credentials
      ;;
    view)
      view_credential
      ;;
    copy)
      copy_field
      ;;
    search)
      search_credentials "${2:-}"
      ;;
    delete)
      delete_credential
      ;;
    ""|-h|--help)
      print_usage
      ;;
    *)
      echo "Unknown or missing command: '$command'" >&2
      print_usage
      return 1
      ;;
  esac
}

main "$@"
