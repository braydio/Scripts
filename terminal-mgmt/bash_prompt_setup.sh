# ~/.bash_prompt_setup

# === Prompt Setup (Hyprland-aware, no external deps) ===

# Optional: set PROMPT_DEBUG=1 before sourcing to see detection logs
PROMPT_DEBUG="${PROMPT_DEBUG:-0}"

detect_terminal_id() {
  # 1) Prefer Hyprland active window info (Wayland)
  if command -v hyprctl >/dev/null 2>&1 && [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    local json class appid
    json="$(hyprctl -j activewindow 2>/dev/null || true)"
    if [[ -n "$json" ]]; then
      class="$(printf '%s\n' "$json" | sed -n 's/.*"class":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
      appid="$(printf '%s\n' "$json" | sed -n 's/.*"initialClass":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
      if [[ -n "$class" ]]; then
        echo "$class"
        return 0
      fi
      if [[ -n "$appid" ]]; then
        echo "$appid"
        return 0
      fi
    fi
  fi

  # 2) Fall back to TERM_PROGRAM if provided by the terminal
  if [[ -n "${TERM_PROGRAM:-}" ]]; then
    echo "$TERM_PROGRAM"
    return 0
  fi

  # 3) Fall back to parent process inspection (coarse but safe)
  local p="$PPID" name tries=0
  while [[ "$p" -gt 1 && "$tries" -lt 6 ]]; do
    name="$(ps -o comm= -p "$p" 2>/dev/null || true)"
    case "$name" in
      kitty|Kitty) echo "kitty"; return 0 ;;
      ghostty|Ghostty) echo "com.mitchellh.ghostty"; return 0 ;;
      warp|Warp|WarpTerminal|warp-launcher) echo "WarpTerminal"; return 0 ;;
      wezterm|WezTerm) echo "wezterm"; return 0 ;;
      alacritty|Alacritty) echo "alacritty"; return 0 ;;
    esac
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ' || echo 1)"
    tries=$((tries+1))
  done

  echo "unknown"
  return 0
}

load_prompt_for_terminal() {
  local id="$1"
  local normalized="other"

  case "$id" in
    WarpTerminal|Warp|dev.warp.Warp) normalized="warp" ;;
    # kitty|Kitty) normalized="kitty" ;;
    com.mitchellh.ghostty|ghostty|Ghostty) normalized="ghostty" ;;
    *) normalized="other" ;;
  esac

  if [[ "$PROMPT_DEBUG" == "1" ]]; then
    echo "[prompt] detected terminal id='$id' normalized='$normalized'"
  fi

  # Load Starship for Warp, Kitty, and Ghostty
  if [[ "$normalized" == "warp" || "$normalized" == "kitty" || "$normalized" == "ghostty" ]]; then
    if command -v starship >/dev/null 2>&1; then
      export STARSHIP_SHELL_INTEGRATION=0
      eval "$(starship init bash)"
      [[ "$PROMPT_DEBUG" == "1" ]] && echo "[prompt] starship loaded"
      return 0
    else
      [[ "$PROMPT_DEBUG" == "1" ]] && echo "[prompt] starship not found; falling back"
    fi
  fi

  # Fallback: Liquidprompt if available, else simple PS1
  if [ -f /usr/bin/liquidprompt ]; then
    # shellcheck disable=SC1091
    source /usr/bin/liquidprompt
    [[ "$PROMPT_DEBUG" == "1" ]] && echo "[prompt] liquidprompt loaded"
  else
    PS1='\[\e[0;32m\][\u@\h \W]\$ \[\e[m\]'
    [[ "$PROMPT_DEBUG" == "1" ]] && echo "[prompt] simple PS1 loaded"
  fi
}

# Execute prompt load with robust detection
load_prompt_for_terminal "$(detect_terminal_id)"
`
