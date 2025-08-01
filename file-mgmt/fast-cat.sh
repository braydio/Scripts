#!/bin/bash

# Aggregates files and directories into a single concatenated file named ".fastcat.local"
# Uses a filelist (default: 'fastcat') in the current directory if available, or all files in current dir otherwise.
# Supports exclusion via an exclude list (default: 'nocat').
# Includes a directory mapping and excludes unsupported file formats by default.

# Script metadata
SCRIPT_NAME="FastCat"
SCRIPT_VERSION="1.9.0"

echo -e "\e[34m$SCRIPT_NAME - Version $SCRIPT_VERSION\e[0m"
echo

# Colors for output
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Default settings
DEFAULT_DIR=$(pwd)
CONCAT_FILE_NAME=".fastcat.local"
FILELIST_NAME="fastcat"
EXCLUDE_FILE="nocat"
MAPPING_DEPTH=2

TREE_MAP_PATH="$DEFAULT_DIR/.tree-map.txt"
MAP_ONLY=false
UNSUPPORTED_EXTENSIONS=("*.exe" "*.bin" "*.iso" "*.img" "*.mp4" "*.avi" "*.mkv" "*.mp3" "*.flac" "*.zip" "*.tar.gz" "*.rar")

# Function to display help/usage
show_help() {
  echo "Aggregates files and directories into a single concatenated file (.fastcat.local)"
  echo "If a filelist is specified with -f or --file, each line is treated as a file or directory to process."
  echo "If not specified, will look for a file named 'fastcat' in the current directory by default."
  echo "Otherwise, all supported files in the current directory are processed."
  echo "Files/directories listed in an exclude list (--nocat <file>, default: 'nocat') are always excluded if present."
  echo
  echo "Usage: fastcat [options]"
  echo
  echo "Options:"
  echo "  -h, --help                Show this help message and exit."
  echo "  -d, --dir <dir>           Target a directory to recursively process (can be repeated)."
  echo "  -f, --file <file>         Specify a file list to use (default: 'fastcat' in the current directory)."
  echo "      --nocat <file>        Specify a file list of files/directories to exclude (default: 'nocat' in the current directory)."
  echo "  -m, --map-depth <n>       Set directory tree map depth (default: 2)."
  echo "      --map-only            Only output the directory tree, don't generate the aggregate file."
  echo
  echo "Notes:"
  echo "  - If no -d or -f is provided, and no 'fastcat' file exists, all supported files in the current directory are processed."
  echo "  - If a file list is given with -f or if 'fastcat' exists, only those files/directories are processed (one per line)."
  echo "  - If --nocat <file> is given or 'nocat' exists, files/directories listed are excluded."
  echo "  - Known binary, media, or archive extensions are always excluded."
  echo "  - Directory tree mapping is output to .tree-map.txt."
  echo
  exit 0
}

# Parse arguments
TARGET_DIRS=()
USE_FILELIST=false
USER_FILELIST=""
USER_EXCLUDELIST=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help) show_help ;;
  -d | --dir)
    TARGET_DIRS+=("$2")
    shift
    ;;
  -f | --file)
    USER_FILELIST="$2"
    shift
    ;;
  --nocat)
    USER_EXCLUDELIST="$2"
    shift
    ;;
  -m | --map-depth)
    MAPPING_DEPTH="$2"
    shift
    ;;
  --map-only) MAP_ONLY=true ;;
  *)
    echo -e "${RED}Unknown argument: $1${RESET}"
    exit 1
    ;;
  esac
  shift
done

# Use specified filelist if provided, then fallback to default
if [[ -n "$USER_FILELIST" ]] && [[ -f "$DEFAULT_DIR/$USER_FILELIST" ]]; then
  echo -e "${YELLOW}Using filelist: $USER_FILELIST${RESET}"
  mapfile -t TARGET_DIRS <"$DEFAULT_DIR/$USER_FILELIST"
  USE_FILELIST=true
elif [[ -f "$DEFAULT_DIR/$FILELIST_NAME" ]]; then
  echo -e "${YELLOW}Using filelist: $FILELIST_NAME${RESET}"
  mapfile -t TARGET_DIRS <"$DEFAULT_DIR/$FILELIST_NAME"
  USE_FILELIST=true
fi

# Default to current directory if no filelist and no dirs specified
if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  echo -e "${YELLOW}No filelist -- $FILELIST_NAME or -f flag detected. Defaulting to current directory.${RESET}"
  TARGET_DIRS+=("$DEFAULT_DIR")
fi

# Read exclude file if specified or if default exists
EXCLUDE_LIST=()
if [[ -n "$USER_EXCLUDELIST" ]] && [[ -f "$DEFAULT_DIR/$USER_EXCLUDELIST" ]]; then
  echo -e "${YELLOW}Using exclusion list: $USER_EXCLUDELIST${RESET}"
  mapfile -t EXCLUDE_LIST <"$DEFAULT_DIR/$USER_EXCLUDELIST"
elif [[ -f "$DEFAULT_DIR/$EXCLUDE_FILE" ]]; then
  echo -e "${YELLOW}Using exclusion list: $EXCLUDE_FILE${RESET}"
  mapfile -t EXCLUDE_LIST <"$DEFAULT_DIR/$EXCLUDE_FILE"
fi

# Expand wildcard exclusions from exclusion file
EXCLUDED_EXTENSIONS=()
for EXCLUDE in "${EXCLUDE_LIST[@]}"; do
  if [[ "$EXCLUDE" == *.* ]]; then
    EXCLUDED_EXTENSIONS+=("*$EXCLUDE")
  fi
done

# Merge default unsupported file formats with user-defined exclusions
ALL_EXCLUDED_EXTENSIONS=("${UNSUPPORTED_EXTENSIONS[@]}" "${EXCLUDED_EXTENSIONS[@]}")

# Notify user of concatenated file location
CONCAT_FILE_PATH="$DEFAULT_DIR/$CONCAT_FILE_NAME"
>"$CONCAT_FILE_PATH"

# Display directory mapping
echo -e "${GREEN}Directory Mapping:${RESET}"
for DIR in "${TARGET_DIRS[@]}"; do
  echo -e "  ${YELLOW}$DIR${RESET}"
done
echo ""

# Function to check if a file or directory is excluded
is_excluded() {
  local ITEM="$1"
  for EXCLUDED in "${EXCLUDE_LIST[@]}"; do
    if [[ "$ITEM" == *"$EXCLUDED"* ]]; then
      return 0
    fi
  done
  for EXT in "${ALL_EXCLUDED_EXTENSIONS[@]}"; do
    if [[ "$ITEM" == $EXT ]]; then
      return 0
    fi
  done
  return 1
}

# Recursive function to print the directory tree
print_tree() {
  local DIR="$1"
  local PREFIX="$2"
  local DEPTH="$3"

  if ((DEPTH > MAPPING_DEPTH)); then
    return
  fi

  local ENTRIES=("$DIR"/*)
  local TOTAL=${#ENTRIES[@]}
  local COUNT=0

  for ENTRY in "${ENTRIES[@]}"; do
    ((COUNT++))
    local CONNECTOR="├──"
    local NEXT_PREFIX="$PREFIX│   "
    if [ "$COUNT" -eq "$TOTAL" ]; then
      CONNECTOR="└──"
      NEXT_PREFIX="$PREFIX    "
    fi

    if [ -d "$ENTRY" ]; then
      echo -e "${PREFIX}${CONNECTOR} ${YELLOW}$(basename "$ENTRY")${RESET}"
      echo -e "${PREFIX}${CONNECTOR} $(basename "$ENTRY")" >>"$TREE_MAP_PATH"
      print_tree "$ENTRY" "$NEXT_PREFIX" $((DEPTH + 1))
    elif [ -f "$ENTRY" ]; then
      echo -e "${PREFIX}${CONNECTOR} $(basename "$ENTRY")"
      echo -e "${PREFIX}${CONNECTOR} $(basename "$ENTRY")" >>"$TREE_MAP_PATH"
    fi
  done
}

echo -e "${GREEN}Directory Tree Mapping (Depth: $MAPPING_DEPTH):${RESET}"
echo "Directory Tree Mapping" >"$TREE_MAP_PATH"
for DIR in "${TARGET_DIRS[@]}"; do
  if [ -d "$DIR" ]; then
    echo -e "${YELLOW}${DIR}${RESET}" | tee -a "$TREE_MAP_PATH"
    print_tree "$DIR" "" 1
  elif [ -f "$DIR" ]; then
    echo -e "${YELLOW}File: $DIR${RESET}" | tee -a "$TREE_MAP_PATH"
  else
    echo -e "${RED}Invalid target: $DIR${RESET}" | tee -a "$TREE_MAP_PATH"
  fi
done
echo ""

if [ "$MAP_ONLY" = true ]; then
  echo -e "${YELLOW}Map-only mode enabled. Skipping concatenation.${RESET}"
  echo -e "${GREEN}Tree map saved to: $TREE_MAP_PATH${RESET}"
  exit 0
fi

# Counters for success and failure
success_count=0
failure_count=0

# Process each file or directory
for TARGET in "${TARGET_DIRS[@]}"; do
  TARGET=$(eval echo "$TARGET") # Expand variables or ~
  if [ -d "$TARGET" ]; then
    if is_excluded "$TARGET"; then
      echo -e "${YELLOW}Skipping excluded directory: $TARGET${RESET}"
      continue
    fi
    echo -e "${GREEN}Processing directory: $TARGET${RESET}"
    for FILE in "$TARGET"/*; do
      if [ -f "$FILE" ]; then
        if is_excluded "$FILE"; then
          echo -e "${YELLOW}Skipping excluded file: $FILE${RESET}"
          continue
        fi
        echo "=== $(basename "$FILE") ===" >>"$CONCAT_FILE_PATH"
        cat "$FILE" >>"$CONCAT_FILE_PATH" && echo -e "\n\n" >>"$CONCAT_FILE_PATH"
        echo -e "${GREEN}Added $FILE to $CONCAT_FILE_NAME${RESET}"
        ((success_count++))
      fi
    done
  elif [ -f "$TARGET" ]; then
    if is_excluded "$TARGET"; then
      echo -e "${YELLOW}Skipping excluded file: $TARGET${RESET}"
      continue
    fi
    echo -e "${GREEN}Processing file: $TARGET${RESET}"
    echo "=== $(basename "$TARGET") ===" >>"$CONCAT_FILE_PATH"
    cat "$TARGET" >>"$CONCAT_FILE_PATH" && echo -e "\n\n" >>"$CONCAT_FILE_PATH"
    echo -e "${GREEN}Added $TARGET to $CONCAT_FILE_NAME${RESET}"
    ((success_count++))
  else
    echo -e "${RED}Target not found: $TARGET${RESET}"
    ((failure_count++))
  fi
done

# Notify user of completion
echo -e "${GREEN}Concatenation complete.${RESET}"
echo -e "${GREEN}$success_count${RESET} files added, ${RED}$failure_count${RESET} targets failed."
echo -e "${GREEN}Output saved to: $CONCAT_FILE_PATH${RESET}"

# Copy the output file to the clipboard
if command -v xclip &>/dev/null; then
  xclip -selection clipboard <"$CONCAT_FILE_PATH"
  echo -e "${GREEN}Copied .fastcat.local to clipboard using xclip.${RESET}"
elif command -v xsel &>/dev/null; then
  xsel --clipboard <"$CONCAT_FILE_PATH"
  echo -e "${GREEN}Copied .fastcat.local to clipboard using xsel.${RESET}"
else
  echo -e "${YELLOW}Neither xclip nor xsel is installed. Cannot copy to clipboard.${RESET}"
fi
