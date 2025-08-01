#!/usr/bin/env bash

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="System Info Collector ArchDesk"
SCRIPT_VERSION="auto"

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

BASE_DIR="$HOME/Uploads/ArchDesk"
FILELIST="$HOME/Uploads/ArchDesk/upload-files.txt"
SCRIPT_DIR="$BASE_DIR/scripts"
LOG_FILE="$BASE_DIR/logs/copy_failures.log"
SYSTEM_INFO_FILE="$BASE_DIR/system-info/sys.txt"
PACKAGES_FILE="$BASE_DIR/pacman-installs.txt"
README_FILE="$BASE_DIR/README.md"
FASTCAT_SCRIPT="$SCRIPT_DIR/fast-cat.sh"

UPLOAD_DEST="$BASE_DIR/upload"

# === SETUP ===

mkdir -p "$BASE_DIR/logs" "$BASE_DIR/system-info"

# Clean output directories
echo -e "${YELLOW}Cleaning upload directory and system-info...${RESET}"
rm -rf "$UPLOAD_DEST" "$BASE_DIR/system-info"/*
mkdir -p "$UPLOAD_DEST"

>"$LOG_FILE"

success_count=0
failure_count=0

# === FUNCTIONS ===

copy_file() {
  local file_path="$1"
  local parent_dir
  parent_dir="$(basename "$(dirname "$file_path")")"
  mkdir -p "$UPLOAD_DEST/$parent_dir"
  if cp "$file_path" "$UPLOAD_DEST/$parent_dir/"; then
    echo -e "${GREEN}Copied $file_path -> $UPLOAD_DEST/$parent_dir/${RESET}"
    ((success_count++))
  else
    echo -e "${RED}Failed to copy $file_path${RESET}" | tee -a "$LOG_FILE"
    ((failure_count++))
  fi
}

copy_directory() {
  local dir_path="$1"
  local parent_dir
  parent_dir="$(basename "$dir_path")"
  mkdir -p "$UPLOAD_DEST/$parent_dir"
  if cp -r "$dir_path/"* "$UPLOAD_DEST/$parent_dir/" 2>/dev/null; then
    echo -e "${GREEN}Copied directory $dir_path -> $UPLOAD_DEST/$parent_dir/${RESET}"
    ((success_count++))
  else
    echo -e "${RED}Failed to copy directory $dir_path${RESET}" | tee -a "$LOG_FILE"
    ((failure_count++))
  fi
}

sync_all() {
  echo "Starting full sync..."
  rm -rf "$UPLOAD_DEST"
  mkdir -p "$UPLOAD_DEST"

  while IFS= read -r ENTRY || [[ -n "$ENTRY" ]]; do
    [[ -z "$ENTRY" || "$ENTRY" == \#* ]] && continue
    ENTRY="$(eval echo "$ENTRY")"

    if [ -f "$ENTRY" ]; then
      copy_file "$ENTRY"
    elif [ -d "$ENTRY" ]; then
      copy_directory "$ENTRY"
    else
      echo -e "${RED}File or directory not found: $ENTRY${RESET}" | tee -a "$LOG_FILE"
      ((failure_count++))
    fi
  done <"$FILELIST"

  echo -e "${GREEN}Sync complete. Files are ready in: $UPLOAD_DEST${RESET}"
}

save_system_info() {
  {
    echo "==== System Info for $(hostname) at $(date) ===="
    if command -v inxi >/dev/null; then
      inxi -Fzx
    else
      echo "inxi not installed"
    fi
    echo "==== Memory Info (free -h) ===="
    free -h
    echo "==== Disk Usage (df -h) ===="
    df -h
    echo "==== Wayland Variables ===="
    env | grep WAYLAND || true
  } >"$SYSTEM_INFO_FILE"

  if command -v pacman >/dev/null; then
    pacman -Qqe >"$PACKAGES_FILE"
    echo -e "${GREEN}Saved installed packages to $PACKAGES_FILE${RESET}"
  else
    echo -e "${RED}Pacman not found. Skipping package list.${RESET}"
  fi
}

generate_readme() {
  if [[ -x "$FASTCAT_SCRIPT" ]]; then
    echo -e "${YELLOW}Generating directory tree map with fast-cat...${RESET}"
    bash "$FASTCAT_SCRIPT" "$UPLOAD_DEST" >"$README_FILE"
    echo -e "${GREEN}Tree map written to $README_FILE${RESET}"
  else
    echo -e "${RED}fast-cat.sh not found or not executable: $FASTCAT_SCRIPT${RESET}"
  fi
}

commit_changes() {
  cd "$BASE_DIR"
  version_file="$BASE_DIR/.version"
  version=$(<"$version_file" 2>/dev/null || echo "0")
  new_version=$((version + 1))
  echo "$new_version" >"$version_file"
  timestamp=$(date '+%Y-%m-%d %H:%M')
  [ -d .git ] || git init
  git add .
  git commit -m "Version $new_version - $timestamp" || echo "No changes to commit."
  git push || echo "Git push failed, check connection."
}

# === MAIN PROCESS ===

echo "Running initial sync..."
sync_all
save_system_info
generate_readme
commit_changes

echo -e "${GREEN}$success_count successful, ${RED}$failure_count failed.${RESET}"
echo -e "${GREEN}Version committed and pushed.${RESET}"

# === WATCH MODE ===

if command -v inotifywait >/dev/null 2>&1; then
  echo "Starting watch mode (real-time sync)..."
  watch_list=()
  while IFS= read -r ENTRY || [[ -n "$ENTRY" ]]; do
    [[ -z "$ENTRY" || "$ENTRY" == \#* ]] && continue
    ENTRY="$(eval echo "$ENTRY")"
    watch_list+=("$ENTRY")
  done <"$FILELIST"

  while true; do
    inotifywait -e modify,create,delete,move "${watch_list[@]}" 2>/dev/null
    echo "Change detected, syncing..."
    sync_all
    save_system_info
    generate_readme
    commit_changes
    sleep 1
  done
else
  echo "inotifywait not found. Install 'inotify-tools' to enable real-time sync."
fi
