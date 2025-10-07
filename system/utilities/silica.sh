#!/usr/bin/env bash

# --------- THEMES ---------
declare -A THEMES
THEMES[dracula.background]="#282C34"
THEMES[dracula.theme]="Dracula"
THEMES[dracula.font]="SpaceMono Nerd Font Mono"

THEMES[nord.background]="#2E3440"
THEMES[nord.theme]="Nord"
THEMES[nord.font]="InputMono Nerd Font"

THEMES[gruvbox.background]="#282828"
THEMES[gruvbox.theme]="Gruvbox Dark"
THEMES[gruvbox.font]="JetBrains Mono"

THEMES[solarized - dark.background]="#002b36"
THEMES[solarized - dark.theme]="Solarized (dark)"
THEMES[solarized - dark.font]="Hack"

# --------- HELPERS ---------
usage() {
  echo "Usage: silica <file.py> [theme]"
  echo "Themes: dracula (default), nord, gruvbox, solarized-dark"
  exit 1
}

next_filename() {
  base="code"
  ext=".png"
  i=1
  filename="${base}${ext}"
  while [[ -f "$filename" ]]; do
    ((i++))
    filename="${base}_${i}${ext}"
  done
  echo "$filename"
}

# --------- PARSE ARGS ---------
[[ $# -lt 1 ]] && usage
INPUT="$1"
[[ ! -f "$INPUT" ]] && echo "File not found: $INPUT" && exit 1

THEME_KEY="${2:-dracula}"
THEME_KEY="${THEME_KEY,,}"

if [[ -z "${THEMES[$THEME_KEY.theme]}" ]]; then
  echo "Unknown theme: $THEME_KEY"
  usage
fi

# --------- CONFIG ---------
OUTPUT=$(next_filename)
BG="${THEMES[$THEME_KEY.background]}"
SILICON_THEME="${THEMES[$THEME_KEY.theme]}"
FONT="${THEMES[$THEME_KEY.font]}"

# --------- RUN SILICON ---------
silicon "$INPUT" \
  --output "$OUTPUT" \
  --background "$BG" \
  --line-offset 7 \
  --line-pad 10 \
  --no-window-controls \
  --shadow-blur-radius 5 \
  --shadow-color "#000000" \
  --shadow-offset-x 3 \
  --shadow-offset-y 3 \
  --code-pad-right 30 \
  --pad-horiz 40 \
  --pad-vert 30 \
  --tab-width 4 \
  --theme "$SILICON_THEME" \
  --no-line-number \
  --font "$FONT"

# --------- CLIPBOARD (Hyprland, xclip) ---------
if command -v xclip >/dev/null; then
  xclip -selection clipboard -t image/png -i "$OUTPUT"
  echo "Copied $OUTPUT to clipboard."
else
  echo "xclip not found, can't copy to clipboard."
fi

echo "Output: $OUTPUT"
