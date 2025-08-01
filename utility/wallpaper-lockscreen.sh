#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
LOCKSCREEN_DIR="$HOME/Pictures/Lockscreen"

mkdir -p "$LOCKSCREEN_DIR"

shopt -s nullglob

for img in "$WALLPAPER_DIR"/*.{png,jpg,jpeg,JPG,JPEG,PNG}; do
  filename=$(basename "$img")
  output="$LOCKSCREEN_DIR/$filename"

  style=$((RANDOM % 2))

  if [[ $style -eq 0 ]]; then
    # 🪞 Olden Style
    echo "Applying 'Olden' effect to $filename"
    magick "$img" \
      -resize 1920x1080^ -gravity center -extent 1920x1080 \
      -blur 0x3 \
      -modulate 100,70 \
      -fill '#704214' -colorize 10% \
      -vignette 0x20 \
      -noise Gaussian \
      "$output"
  else
    # 🧊 Futuristic Style
    echo "Applying 'Futuristic' effect to $filename"
    magick "$img" \
      -resize 1920x1080^ -gravity center -extent 1920x1080 \
      -blur 0x5 \
      -contrast -contrast \
      -fill '#89b4fa' -colorize 15% \
      -modulate 110,130 \
      "$output"
  fi

done

shopt -u nullglob
