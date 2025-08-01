#!/bin/bash

WAYBAR_CSS="$HOME/.config/waybar/way_colors.css"
WALLPAPER="$HOME/Pictures/Wallpapers/input.png"
OUTPUT_WALL="$HOME/Pictures/Wallpapers/Earth.png"

# Define a theme palette (Catppuccin Mocha as an example)
theme_colors=(
  "#f4dbd6" "#f0c6c6" "#f5bde6" "#c6a0f6" "#ed8796" "#ee99a0" "#f5a97f"
  "#eed49f" "#8bd5ca" "#91d7e3" "#7dc4e4" "#8aadf4" "#b7bdf8" "#cad3f5"
  "#b8c0e0" "#a5adcb" "#939ab7" "#8087a2" "#6e738d" "#5b6078" "#494d64"
  "#363a4f" "#24273a" "#1e2030" "#181926"
)

# Corresponding variable names (from your original way_colors.css)
color_names=(
  darkblue rosewater flamingo pink mauve red maroon peach yellow
  teal sky sapphire blue lavender text subtext1 subtext0 overlay2
  overlay1 overlay0 surface2 surface1 surface0 base mantle crust
)

echo "🎨 Shuffling themed palette for Waybar..."
shuffled_colors=($(printf "%s\n" "${theme_colors[@]}" | shuf))

mkdir -p "$(dirname "$WAYBAR_CSS")"
>"$WAYBAR_CSS"

for i in "${!color_names[@]}"; do
  echo "@define-color ${color_names[$i]} ${shuffled_colors[$i]};" >>"$WAYBAR_CSS"
done

# Use one of the shuffled colors for wallpaper tint — pick e.g. lavender
TINT_VAR="lavender"
TINT_HEX=$(grep "@define-color $TINT_VAR" "$WAYBAR_CSS" | awk '{print $3}')

echo "🖼️ Tinting wallpaper using $TINT_VAR = $TINT_HEX..."

if [ -f "$WALLPAPER" ]; then
  magick "$WALLPAPER" \
    \( -size 1920x1080 xc:"$TINT_HEX" -alpha set -channel A -evaluate set 35% \) \
    -compose over -composite "$OUTPUT_WALL"
  echo "✅ Tinted wallpaper saved to $OUTPUT_WALL"
else
  echo "❌ Wallpaper not found at $WALLPAPER"
fi
