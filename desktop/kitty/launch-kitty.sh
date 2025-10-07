#!/bin/bash

# Directory containing Kitty themes
THEME_DIR="$HOME/.config/kitty"

# Find all available theme files (*.conf) and extract the theme names (without .conf extension)
THEMES=($(ls "$THEME_DIR" | sed 's/\.conf$//'))

# Pick a random theme from the list
SELECTED_THEME=${THEMES[$RANDOM % ${#THEMES[@]}]}

# Launch Kitty with the selected theme without focusing
nohup kitty --override include="$THEME_DIR/$SELECTED_THEME.conf" > /dev/null 2>&1 &

