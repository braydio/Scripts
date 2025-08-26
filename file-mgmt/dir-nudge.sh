#!/usr/bin/env bash
# dir-nudge.sh — Nudge you every run to deal with exactly ONE file/dir.
# Intended to be triggered by a systemd --user timer every 25 minutes.
# Requires: zenity; optional: trash-cli or gio (for Trash).
set -Eeuo pipefail

# ----- Config -----
CANDIDATE_DIRS=("$HOME/Downloads" "$HOME/.config" "$HOME/Projects" "$HOME/")
DIRINDEX="${HOME}/.dirindex"                # "directory directory"
IGNORED_DIR="${DIRINDEX}/ignored"           # stores symlinks you chose to ignore
IGNORE_LIST="${DIRINDEX}/ignored_paths.txt" # authoritative ignore list (absolute paths)
LOG_FILE="${DIRINDEX}/actions.log"
DEFAULT_MOVE_DEST="${HOME}/Archive" # default destination when you choose "Move"
MAXDEPTH=1                          # only top-level items in each parent dir
# -------------------

mkdir -p "$DIRINDEX" "$IGNORED_DIR" "$DEFAULT_MOVE_DEST"
touch "$IGNORE_LIST" "$LOG_FILE"

# Prevent concurrent runs.
exec 9>"${DIRINDEX}/.lock"
if ! flock -n 9; then
  exit 0
fi

# Helper: true if $1 exists in ignore list (by canonical absolute path)
is_ignored() {
  local p real
  p="$1"
  real="$(realpath -m -- "$p" 2>/dev/null || true)"
  [[ -z "$real" ]] && return 1
  grep -Fxq -- "$real" "$IGNORE_LIST"
}

# Helper: add to ignore list + drop a symlink into ~/.dirindex/ignored
add_ignore() {
  local p="$1"
  local real link_name base ts
  real="$(realpath -m -- "$p")"
  if ! is_ignored "$real"; then
    echo "$real" >>"$IGNORE_LIST"
  fi
  base="$(basename -- "$p")"
  ts="$(date +%s)"
  link_name="${IGNORED_DIR}/${base}.${ts}.lnk"
  ln -sfn -- "$real" "$link_name" 2>/dev/null || true
}

# Choose ONE candidate, oldest mtime first, skipping ignores and ~/.dirindex
choose_candidate() {
  # Build a list of eligible items with mtime
  # Format: "<epoch>|<absolute-path>"
  local list=()
  for parent in "${CANDIDATE_DIRS[@]}"; do
    [[ -d "$parent" ]] || continue
    # Exclude hidden names at this depth; exclude our index; exclude . and ..
    while IFS= read -r -d '' p; do
      # Skip anything inside ~/.dirindex
      [[ "$p" == "$DIRINDEX"* ]] && continue
      # Skip if ignored
      is_ignored "$p" && continue
      # Skip hidden base names
      local bn
      bn="$(basename -- "$p")"
      [[ "$bn" == .* ]] && continue
      # Capture mtime
      local mt
      mt="$(stat -c '%Y' -- "$p" 2>/dev/null || echo 0)"
      list+=("${mt}|${p}")
    done < <(find -L "$parent" -maxdepth "$MAXDEPTH" -mindepth 1 -not -path '*/.*' -print0 2>/dev/null || true)
  done

  [[ ${#list[@]} -eq 0 ]] && return 1
  # Sort by mtime (ascending) and pick the oldest
  IFS=$'\n' read -r -d '' oldest < <(printf '%s\0' "${list[@]}" | sort -z -n | head -z -n 1 || true)
  local candidate="${oldest#*|}"
  [[ -n "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

# Present a Zenity choice for exactly one item
handle_one() {
  local target="$1"
  local bn size mod
  bn="$(basename -- "$target")"
  size="$(du -sh -- "$target" 2>/dev/null | awk '{print $1}')"
  mod="$(date -d "@$(stat -c '%Y' -- "$target" 2>/dev/null || date +%s)" '+%Y-%m-%d %H:%M:%S')"

  # Build action prompt
  local action
  action="$(
    zenity --list \
      --title="Tidy: ${bn}" \
      --text="Path: ${target}\nSize: ${size}\nModified: ${mod}\n\nChoose an action for this item:" \
      --column="Action" "Move" "Remove" "Ignore" "Skip" \
      --height=260 --width=650 2>/dev/null || echo ""
  )"

  [[ -z "$action" ]] && action="Skip"

  case "$action" in
  Move)
    local dest
    dest="$(
      zenity --file-selection --directory \
        --title="Select destination (default: ${DEFAULT_MOVE_DEST})" \
        --filename="${DEFAULT_MOVE_DEST}/" 2>/dev/null || echo ""
    )"
    [[ -z "$dest" ]] && dest="$DEFAULT_MOVE_DEST"
    mkdir -p -- "$dest"
    # If dest is the same dir as source parent, do nothing
    if [[ "$(realpath -m -- "$dest")" == "$(realpath -m -- "$(dirname -- "$target")")" ]]; then
      :
    else
      mv -n -- "$target" "$dest"/
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "MOVE" "$target" "$dest" "$USER" >>"$LOG_FILE"
    ;;
  Remove)
    if zenity --question --title="Confirm removal" --text="Send to Trash?\n${target}" 2>/dev/null; then
      if command -v gio >/dev/null 2>&1; then
        gio trash -- "$target" 2>/dev/null || rm -rf -- "$target"
      elif command -v trash-put >/dev/null 2>&1; then
        trash-put -- "$target" 2>/dev/null || rm -rf -- "$target"
      else
        rm -rf -- "$target"
      fi
      printf '%s\t%s\t%s\t-\t%s\n' "$(date -Is)" "REMOVE" "$target" "$USER" >>"$LOG_FILE"
    else
      printf '%s\t%s\t%s\t-\t%s\n' "$(date -Is)" "CANCEL_REMOVE" "$target" "$USER" >>"$LOG_FILE"
    fi
    ;;
  Ignore)
    add_ignore "$target"
    printf '%s\t%s\t%s\t-\t%s\n' "$(date -Is)" "IGNORE" "$target" "$USER" >>"$LOG_FILE"
    ;;
  Skip | *)
    printf '%s\t%s\t%s\t-\t%s\n' "$(date -Is)" "SKIP" "$target" "$USER" >>"$LOG_FILE"
    ;;
  esac
}

main() {
  # Verify Zenity presence
  if ! command -v zenity >/dev/null 2>&1; then
    printf 'Zenity not found. Install with: sudo pacman -S zenity\n' >&2
    exit 1
  fi

  local cand
  if ! cand="$(choose_candidate)"; then
    # nothing to do today; stay silent
    exit 0
  fi
  handle_one "$cand"
}

main "$@"
