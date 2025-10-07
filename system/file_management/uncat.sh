#!/bin/bash

# Fast Un-Cat - Reconstructs individual files from .fastcat.txt
SCRIPT_NAME="UnCat Fastcat"
SCRIPT_VERSION="1.0.0"

echo -e "\e[34m$SCRIPT_NAME - Version $SCRIPT_VERSION\e[0m\n"

INPUT_FILE=".fastcat.txt"
OUTPUT_DIR="./uncat_output"
mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo -e "\e[31mError: $INPUT_FILE not found in the current directory.\e[0m"
  exit 1
fi

current_file=""
success_count=0

while IFS= read -r line; do
  if [[ "$line" =~ ^===\ (.+)\ ===$ ]]; then
    current_file="${BASH_REMATCH[1]}"
    echo -e "\e[32mCreating file: $current_file\e[0m"
    exec 3>"$OUTPUT_DIR/$current_file"
    ((success_count++))
  elif [[ -n "$current_file" ]]; then
    echo "$line" >&3
  fi
done <"$INPUT_FILE"

# Close the last file descriptor if open
exec 3>&-

echo -e "\n\e[32mUn-catenation complete.\e[0m"
echo -e "\e[32mExtracted $success_count files to: $OUTPUT_DIR/\e[0m"
