#!/bin/bash
# Script to open DevTools and inject textarea into ChatGPT Desktop App

# Focus ChatGPT window
hyprctl dispatch focuswindow "class:chat-gpt"
sleep 0.2

# Open DevTools (simulating F12 key press)
wtype --key F12
sleep 0.5

# Paste the JavaScript injection into DevTools console
wl-paste --no-newline <<< 'let textarea = document.createElement("textarea"); textarea.id = "prompt-textarea"; textarea.style.width = "100%"; textarea.style.height = "50px"; document.querySelector("#prompt-textarea").replaceWith(textarea);'

# Send Ctrl+Enter to execute the injected code in DevTools
sleep 0.2
wtype --key ctrl+enter
sleep 0.5

# Close DevTools
wtype --key F12

echo "Textarea injected. You can now use clipboard pasting!"

