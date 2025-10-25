#!/bin/bash

X=3200
Y=752

sudo ydotool mousemove $X $Y

while true; do
  sudo ydotool click 0xC0
  sleep 5
done
