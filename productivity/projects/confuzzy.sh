#!/bin/bash

# Define the base directory for projects
CONFIG_DIR=~/.config

# Ensure the projects directory exists
if [ ! -d "$CONFIG_DIR" ]; then
  echo "Error: Config directory $CONFIG_DIR does not exist."
  exit 1
fi

# Check if `fzf` is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: fzf (fuzzy finder) is not installed."
  exit 1
fi

# Use fuzzy finder to select a project
echo "Select a project:"
proj=$(find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -type d | fzf)

# Check if a project was selected
if [ -n "$proj" ]; then
  cd "$proj" || {
    echo "Error: Failed to change directory to $proj"
    exit 1
  }
  echo "Changed directory to $proj"
else
  echo "No project selected."
  exit 1
fi
