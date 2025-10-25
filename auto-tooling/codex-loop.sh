#!/usr/bin/env bash
set -euo pipefail

ISSUE_FILE="issue.txt"
RESTART_FLAG="restart.flag"
CODEX_URL="https://chatgpt.com/codex"
CODEX_ENV_LABEL=${CODEX_ENV_LABEL:-}

codex_eval() {
  local script="$1"
  qutebrowser ":jseval --quiet ${script}" 2>/dev/null
}

escape_js() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//"/\\"}
  value=${value//$'\n'/\\n}
  echo "$value"
}

focus_codex() {
  local addr=""
  local last_addr=""
  while IFS= read -r line; do
    if [[ "$line" =~ address:\ ([^[:space:]]+) ]]; then
      last_addr="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ title:\ (.*) ]]; then
      local title="${BASH_REMATCH[1]}"
      if [[ "$title" == *"chatgpt.com/codex"* ]]; then
        addr="$last_addr"
        break
      fi
    fi
  done < <(hyprctl clients 2>/dev/null || true)

  if [[ -n "$addr" ]]; then
    hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
  fi

  if [[ -z "$addr" ]]; then
    hyprctl dispatch focuswindow "title:Codex - qutebrowser" >/dev/null 2>&1 || true
    hyprctl dispatch focuswindow "class:qutebrowser" >/dev/null 2>&1 || true
  fi
  sleep 1
}

open_codex_tab() {
  if ! pgrep -x qutebrowser >/dev/null 2>&1; then
    qutebrowser "$CODEX_URL" >/dev/null 2>&1 &
  else
    qutebrowser ":open $CODEX_URL" >/dev/null 2>&1 || true
  fi
  sleep 5
}

ensure_codex_ready() {
  local attempts=0
  while true; do
    if ! pgrep -x qutebrowser >/dev/null 2>&1; then
      open_codex_tab
      continue
    fi

    focus_codex
    local state
    state=$(codex_eval "(() => {
      const href = window.location?.href || '';
      if (!href) return 'BLANK';
      if (!href.includes('chatgpt.com')) return 'NAVIGATE';
      if (!href.includes('/codex')) return 'NAVIGATE';

      const loginBtn = Array.from(document.querySelectorAll('button, a'))
        .find(el => /Log in|Sign in|Continue/i.test((el.innerText || '').trim()));
      if (loginBtn) return 'LOGIN';

      const prompt = document.querySelector('#prompt-textarea');
      if (prompt) {
        prompt.focus();
        return 'READY';
      }

      const blockers = Array.from(document.querySelectorAll('[data-testid]'))
        .some(el => /spinner|loading/i.test(el.dataset.testid || ''));
      if (blockers) return 'WAIT';

      return 'WAIT';
    })()" || echo BLANK)

    case "$state" in
      READY)
        break
        ;;
      LOGIN)
        echo ">>> ChatGPT requires login. Please authenticate in the Codex window."
        sleep 6
        ;;
      NAVIGATE)
        open_codex_tab
        ;;
      BLANK|WAIT)
        attempts=$((attempts + 1))
        if (( attempts % 5 == 0 )); then
          echo ">>> Waiting for Codex workspace..."
        fi
        sleep 4
        ;;
      *)
        sleep 3
        ;;
    esac
  done
}

ensure_codex_environment() {
  local label="$CODEX_ENV_LABEL"
  [[ -z "$label" ]] && return 0

  local escaped
  escaped=$(escape_js "$label")

  local result
  result=$(codex_eval "(() => {
    const label = \"${escaped}\";
    const matchesText = (el) => (el.innerText || '').trim() === label;

    const trigger = Array.from(document.querySelectorAll('[data-testid], button, div[role="button"]'))
      .find(matchesText);
    if (!trigger) return 'WAIT';

    const button = trigger.tagName === 'BUTTON' ? trigger : trigger.closest('button, [role="button"]');
    if (!button) return 'WAIT';

    if (button.getAttribute('aria-pressed') === 'true' || button.getAttribute('aria-selected') === 'true') {
      return 'READY';
    }

    button.click();
    return 'CLICK';
  })()" || echo WAIT)

  if [[ "$result" == "WAIT" ]]; then
    echo "[!] Could not find environment selector for '$label'"
  elif [[ "$result" == "CLICK" ]]; then
    echo ">>> Selected Codex environment '$label'"
  fi
}

focus_prompt_box() {
  codex_eval "(() => {
    const box = document.querySelector('#prompt-textarea');
    if (box) {
      box.focus();
      return 'OK';
    }
    return 'MISS';
  })()" >/dev/null 2>&1 || true
  sleep 0.5
}

paste_to_codex() {
  ensure_codex_ready
  ensure_codex_environment
  wl-copy <"$ISSUE_FILE"
  sleep 0.5
  focus_prompt_box
  # Ctrl+V
  ydotool key 29:1 47:1 47:0 29:0
  sleep 0.5
  echo ">>> Pasted issue.txt into Codex"
}

issue_checksum() {
  if [[ ! -s "$ISSUE_FILE" ]]; then
    echo ""
    return
  fi
  sha1sum "$ISSUE_FILE" | awk '{print $1}'
}

click_code_button() {
  local result
  result=$(codex_eval "(() => {
    const candidates = Array.from(document.querySelectorAll('button, span'));
    const codeBtn = candidates.find(el => el.innerText && el.innerText.trim() === 'Code');
    if (!codeBtn) return 'MISS';
    (codeBtn.tagName === 'BUTTON' ? codeBtn : codeBtn.closest('button'))?.click();
    return 'CLICKED';
  })()" || echo MISS)

  if [[ "$result" == *CLICKED* ]]; then
    echo ">>> Clicked Code button"
  else
    echo "[!] Code button not found"
  fi
}

wait_for_task_card() {
  echo ">>> Waiting for Codex to create a task card..."
  while true; do
    local result
    result=$(codex_eval "(() => {
      const cards = Array.from(document.querySelectorAll('span'));
      const target = cards.find(el => el.innerText.trim().startsWith('Fix '));
      if (!target) return 'WAIT';
      target.click();
      return 'FOUND';
    })()" || echo WAIT)
    if [[ "$result" == *FOUND* ]]; then
      echo ">>> Task card opened"
      break
    fi
    sleep 5
  done
}

wait_for_codex_done() {
  echo ">>> Waiting for Codex to finish (Create PR visible)..."
  while true; do
    local result
    result=$(codex_eval "(() => {
      const btn = Array.from(document.querySelectorAll('span.truncate'))
        .find(el => el.innerText.trim() === 'Create PR');
      return btn ? 'FOUND' : 'WAIT';
    })()" || echo WAIT)
    if [[ "$result" == *FOUND* ]]; then
      echo ">>> Codex finished, Create PR visible"
      break
    fi
    sleep 5
  done
}

click_create_pr() {
  local result
  result=$(codex_eval "(() => {
    const btnSpan = Array.from(document.querySelectorAll('span.truncate'))
      .find(el => el.innerText.trim() === 'Create PR');
    if (!btnSpan) return 'MISS';
    btnSpan.closest('button')?.click();
    return 'CLICKED';
  })()" || echo MISS)

  if [[ "$result" == *CLICKED* ]]; then
    echo ">>> Clicked Create PR"
  else
    echo "[!] Failed to click Create PR"
  fi
}

ensure_watch_file() {
  if [[ ! -f "$ISSUE_FILE" ]]; then
    echo ">>> Waiting for $ISSUE_FILE to be created..."
    until [[ -f "$ISSUE_FILE" ]]; do
      sleep 2
    done
  fi
}

process_issue_update() {
  local reason="${1:-update}"
  if [[ "$reason" == "initial" ]]; then
    echo ">>> Processing existing contents of $ISSUE_FILE"
  else
    echo ">>> Detected update to $ISSUE_FILE"
  fi
  paste_to_codex
  click_code_button
  wait_for_task_card
  wait_for_codex_done
  click_create_pr
  touch "$RESTART_FLAG"
  echo ">>> restart.flag touched; awaiting next issue"
}

watch_issue_file() {
  ensure_watch_file
  local last_checksum=""
  if [[ -s "$ISSUE_FILE" ]]; then
    last_checksum=$(issue_checksum)
    process_issue_update initial
  fi
  echo ">>> Watching $ISSUE_FILE for changes"
  inotifywait -m -e close_write "$ISSUE_FILE" | while read -r _ _ _; do
    local current_checksum
    current_checksum=$(issue_checksum)
    if [[ "$current_checksum" == "$last_checksum" ]]; then
      continue
    fi
    last_checksum="$current_checksum"
    process_issue_update
  done
}

ensure_codex_ready
watch_issue_file
