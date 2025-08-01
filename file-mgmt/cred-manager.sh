#!/bin/bash

# Credentials Vault Script
VAULT_DIR="$HOME/Documents/Credentials/"

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

# Function to add a new credential or API key
add_credential() {
  read -p "Enter Entry Type (credential/api): " entry_type
  read -p "Enter Name: " name

  file="$VAULT_DIR/$name.txt"

  echo "TYPE: $entry_type" >"$file"
  echo "NAME: $name" >>"$file"

  if [[ "$entry_type" == "credential" ]]; then
    read -p "Enter Username: " user
    read -sp "Enter Password: " pass
    echo
    echo "USER: $user" >>"$file"
    echo "PASS: $pass" >>"$file"
  elif [[ "$entry_type" == "api" ]]; then
    read -p "Enter API Key: " api_key
    read -p "Enter Client ID (optional): " client_id
    echo "API_KEY: $api_key" >>"$file"
    if [[ -n "$client_id" ]]; then
      echo "CLIENT_ID: $client_id" >>"$file"
    fi
  else
    echo "Unknown entry type. Use 'credential' or 'api'."
    rm "$file"
    exit 1
  fi

  read -p "Enter Notes (optional): " notes
  echo "NOTES: $notes" >>"$file"

  echo "Entry '$name' saved."
}

# Function to list credentials
list_credentials() {
  echo "Available entries:"
  ls "$VAULT_DIR" | sed 's/\.txt$//'
}

# Function to view a credential
view_credential() {
  require_fzf
  local selected=$(ls "$VAULT_DIR" | sed 's/\.txt$//' | fzf --prompt="Select entry to view: ")
  if [[ -n "$selected" ]]; then
    local file="$VAULT_DIR/$selected.txt"
    echo "--- $selected ---"
    cat "$file"
  else
    echo "No entry selected."
  fi
}

# Function to copy a specific field
copy_field() {
  require_fzf
  local selected=$(ls "$VAULT_DIR" | sed 's/\.txt$//' | fzf --prompt="Select entry to copy from: ")
  if [[ -n "$selected" ]]; then
    local file="$VAULT_DIR/$selected.txt"
    local fields=$(grep -o '^[A-Z_]*:' "$file" | sed 's/:$//')
    local field=$(echo "$fields" | fzf --prompt="Select field to copy: ")

    if [[ -n "$field" ]]; then
      value=$(grep "^$field:" "$file" | sed "s/^$field: //")
      if [[ -n "$value" ]]; then
        if [[ -n "$COPY_CMD" ]]; then
          echo -n "$value" | $COPY_CMD
          echo "$field from '$selected' copied to clipboard."
        else
          echo "No clipboard tool found."
        fi
      else
        echo "Field '$field' not found in '$selected'."
      fi
    else
      echo "No field selected."
    fi
  else
    echo "No entry selected."
  fi
}

# Function to search credentials
search_credentials() {
  local query="$1"
  echo "Searching for '$query'..."
  ls "$VAULT_DIR" | grep -i "$query" | sed 's/\.txt$//'
}

# Main Menu
case "$1" in
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
  search_credentials "$2"
  ;;
*)
  echo "Usage: $0 {add|list|view|copy|search} [entry_name] [FIELD(optional for copy)]"
  ;;
esac
