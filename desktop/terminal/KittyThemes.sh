#!/bin/bash

theme_dir="$HOME/.config/kitty/kitty-themes/themes/"

# Ensure fzf is installed
if ! command -v fzf &> /dev/null; then
  echo "fzf is not installed. Please install it using 'sudo pacman -S fzf'."
  exit 1
fi

# If a theme name is provided, apply it directly
if [[ -n "$1" ]]; then
  if [[ -f "$theme_dir/$1.conf" ]]; then
    kitty -o include="$theme_dir/$1.conf"
  else
    echo "Theme '$1' not found."
    exit 1
  fi
  exit 0
fi

# List themes with fzf for interactive selection
theme=$(ls "$theme_dir" | sed 's/\.conf$//' | fzf --prompt="Select a Kitty theme: ")

# Apply selected theme
if [[ -n "$theme" ]]; then
  kitty -o include="$theme_dir/$theme.conf"
else
  echo "No theme selected."
fi

