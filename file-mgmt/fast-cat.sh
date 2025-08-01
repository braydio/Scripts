#!/bin/bash

# Aggregates files and directories into a single concatenated file named ".fastcat.txt"
# Uses `fastcat.txt` in the current directory if available; defaults to the current directory otherwise
# Supports exclusion of files and directories specified in `nocat.txt`
# Now includes a directory mapping and excludes unsupported file formats by default

# Script metadata
SCRIPT_NAME="Fast-Cat"
SCRIPT_VERSION="1.8.0"

# Print script name and version
echo -e "\e[34m$SCRIPT_NAME - Version $SCRIPT_VERSION\e[0m"
echo

# Colors for output
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Default settings
DEFAULT_DIR=$(pwd)
CONCAT_FILE_NAME=".fastcat.txt"
FILELIST_NAME="fastcat.txt"
EXCLUDE_FILE="nocat.txt"
MAPPING_DEPTH=2

TREE_MAP_PATH="$DEFAULT_DIR/.tree-map.txt"
MAP_ONLY=false
UNSUPPORTED_EXTENSIONS=("*.exe" "*.bin" "*.iso" "*.img" "*.mp4" "*.avi" "*.mkv" "*.mp3" "*.flac" "*.zip" "*.tar.gz" "*.rar")

# Function to display help/usage
show_help() {
  echo "Aggregates files and directories into a single concatenated file named .fastcat.txt"
  echo "Uses fastcat.txt in the current directory if available"
  echo "Defaults to all (supported) files in the current directory otherwise"
  echo "Supports exclusion of files and directories flagged or specified in nocat.txt"

  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help            Display this help message and exit."
  echo "  -d, --dir <dir>       Specify a target directory to process."
  echo "  -f, --file <file>     Specify a file to be processed."
  echo "  -m, --map-depth <n>   Set the directory tree map depth (default: 2)."
  echo "  --map-only            Only generate the directory map."
  exit 0
}

# Parse arguments
TARGET_DIRS=()
USE_FILELIST=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h | --help) show_help ;;
  -d | --dir)
    TARGET_DIRS+=("$2")
    shift
    ;;
  -f | --file)
    TARGET_DIRS+=("$2")
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

# Use `fastcat.txt` if it exists and no flags are passed
if [ -f "$DEFAULT_DIR/$FILELIST_NAME" ] && [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  echo -e "${YELLOW}Using filelist: $FILELIST_NAME${RESET}"
  mapfile -t TARGET_DIRS <"$DEFAULT_DIR/$FILELIST_NAME"
  USE_FILELIST=true
fi

# Default to current directory if no filelist and no flags
if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  echo -e "${YELLOW}No filelist -- $FILELIST_NAME or flags detected. Defaulting to current directory.${RESET}"
  TARGET_DIRS+=("$DEFAULT_DIR")
fi

# Read exclude file if it exists
EXCLUDE_LIST=()
if [ -f "$DEFAULT_DIR/$EXCLUDE_FILE" ]; then
  echo -e "${YELLOW}Using exclusion list: $EXCLUDE_FILE${RESET}"
  mapfile -t EXCLUDE_LIST <"$DEFAULT_DIR/$EXCLUDE_FILE"
fi

# Expand wildcard exclusions from nocat.txt
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
      # Print to terminal with color
      echo -e "${PREFIX}${CONNECTOR} ${YELLOW}$(basename "$ENTRY")${RESET}"
      # Print to file without color
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
  echo -e "${GREEN}Copied .fastcat.txt to clipboard using xclip.${RESET}"
elif command -v xsel &>/dev/null; then
  xsel --clipboard <"$CONCAT_FILE_PATH"
  echo -e "${GREEN}Copied .fastcat.txt to clipboard using xsel.${RESET}"
else
  echo -e "${YELLOW}Neither xclip nor xsel is installed. Cannot copy to clipboard.${RESET}"
fi
