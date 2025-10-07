#!/usr/bin/env bash

# 1) Launch your terminal
kitty --title "MyTerm" &
sleep 1

# 2) Launch firefox kiosk
firefox --no-remote --disable-extensions --disable-gpu --kiosk &
sleep 3

# 3) Find kitty window
TERM_ADDRESS=$(hyprctl clients -j |
  jq -r '.[] | select(.title == "MyTerm") | .address' |
  head -n 1)

# 4) Find firefox window
FF_ADDRESS=$(hyprctl clients -j |
  jq -r '.[] | select(.class == "firefox") | .address' |
  head -n 1)

# 5) Move & resize kitty
hyprctl dispatch focuswindow address:$TERM_ADDRESS
hyprctl dispatch movewindowpixel 50 50
hyprctl dispatch resizewindowpixel 800 600

# 6) Move & resize firefox
hyprctl dispatch focuswindow address:$FF_ADDRESS
hyprctl dispatch movewindowpixel 900 50
hyprctl dispatch resizewindowpixel 1000 800

echo "Done! Arranged kitty and firefox."
