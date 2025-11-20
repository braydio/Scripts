#!/usr/bin/env bash
#
# Unified system and developer package updater with LLM log summary
#
# Example:
#   ./package-mgmt/update-all.sh --yes
#   ./package-mgmt/update-all.sh --dry-run --no-llm
#   ./package-mgmt/update-all.sh --system --flatpak --brew --yes --model "llama3.1"
#
# Behavior:
# - Detects available managers (apt, pacman/yay, dnf, brew, flatpak, snap, nix, pipx, pip, npm, cargo, gem)
# - Groups updates by category with flags (system, flatpak, snap, brew, nix, languages, containers)
# - Captures full logs to logs/update-<timestamp>.log and prints live
# - Summarizes the log via local LLM (Ollama at 192.168.1.69:11434) with fallback to LocalAI at localhost:8080
# - Defaults to non-interactive behavior with cleanup; use --manual to require confirmations

set -euo pipefail

print_usage() {
  cat <<'USAGE'
Usage: update-all.sh [options]

Options:
  --system            Update system packages (apt/pacman/dnf/brew) [default: on]
  --flatpak           Update Flatpak apps [default: off]
  --snap              Update Snap packages [default: off]
  --brew              Update Homebrew (if installed) [default: off]
  --nix               Update Nix user profile [default: off]
  --languages         Update language/package tools: pipx, pip (user), npm -g, cargo, gem [default: off]
  --containers        Pull newer images for running Docker containers [default: off]
  --no-llm            Skip sending logs to LLM for summarization
  --model NAME        Model to use for LLM (Ollama or LocalAI) [default: llama3.1]
  --dry-run           Print commands without executing
  --yes, -y           Assume yes to prompts (non-interactive mode) [default]
  --manual            Require confirmations (interactive mode)
  --no-clean          Skip cache cleanup (pacman/yay/paru caches, flatpak unused, etc.)
  --deep-clean        Perform extended cleanup (Docker prune, journal vacuum, build caches)
  --help, -h          Show this help

Environment overrides:
  LLM_OLLAMA_HOST     Default: 192.168.1.69
  LLM_OLLAMA_PORT     Default: 11434 (Ollama default)
  LLM_LOCALAI_URL     Default: http://localhost:8080
  LLM_TGW_HOST        Default: 192.168.1.69
  LLM_TGW_PORT        Default: 5150 (text-generation-webui)
  CLEAN_JOURNAL_FOR   Journal retention for vacuum (e.g., 7d or 200M) [default: 7d]

Notes:
  - Commands are executed only for managers detected on this system.
  - Use --dry-run to verify actions. Combine with --yes to preview non-interactive sequence.
USAGE
}

# Defaults
DO_SYSTEM=1
DO_FLATPAK=0
DO_SNAP=0
DO_BREW=0
DO_NIX=0
DO_LANG=0
DO_CONTAINERS=0
DO_LLM=1

MODEL_NAME="${LLM_MODEL:-llama3.1}"
OLLAMA_HOST="${LLM_OLLAMA_HOST:-192.168.1.69}"
OLLAMA_PORT="${LLM_OLLAMA_PORT:-11434}"
LOCALAI_URL="${LLM_LOCALAI_URL:-http://localhost:8080}"
TGEN_HOST="${LLM_TGW_HOST:-192.168.1.69}"
TGEN_PORT="${LLM_TGW_PORT:-5150}"

DRY_RUN=0
ASSUME_YES=1
CLEAN_AFTER=1
DEEP_CLEAN=0

log_dir="logs"
timestamp="$(date +%Y%m%d-%H%M%S)"
log_file="$log_dir/update-$timestamp.log"
summary_file="$log_dir/update-$timestamp.summary.txt"

_have() { command -v "$1" >/dev/null 2>&1; }

# Resolve a reliable Python 3 interpreter not backed by pyenv shims
_resolve_python3() {
  if [ -x /usr/bin/python3 ]; then
    echo /usr/bin/python3
    return 0
  fi
  local p
  p=$(command -v python3 2>/dev/null || true)
  if [ -n "$p" ]; then
    case "$p" in
      */.pyenv/shims/*) : ;; # ignore shim
      *) echo "$p"; return 0 ;;
    esac
  fi
  p=$(command -v python 2>/dev/null || true)
  if [ -n "$p" ] && "$p" -V 2>&1 | grep -q "Python 3"; then
    echo "$p"
    return 0
  fi
  echo python3
}

PY3_BIN="$(_resolve_python3)"

_run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ $*"
  else
    # shellcheck disable=SC2068
    $@
  fi
}

_sudo_run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ sudo $*"
  else
    # shellcheck disable=SC2068
    sudo $@
  fi
}

confirm() {
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  read -r -p "$1 [y/N]: " reply
  case "$reply" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_log_setup() {
  mkdir -p "$log_dir"
  # Start tee only once when not in dry-run
  if [ "$DRY_RUN" -eq 0 ]; then
    # Redirect both stdout and stderr to tee
    exec > >(tee -a "$log_file") 2>&1
  else
    echo "[DRY-RUN] Logs would be written to: $log_file"
  fi
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --system) DO_SYSTEM=1 ;;
      --flatpak) DO_FLATPAK=1 ;;
      --snap) DO_SNAP=1 ;;
      --brew) DO_BREW=1 ;;
      --nix) DO_NIX=1 ;;
      --languages) DO_LANG=1 ;;
      --containers) DO_CONTAINERS=1 ;;
      --no-llm) DO_LLM=0 ;;
      --model) shift; MODEL_NAME="${1:-$MODEL_NAME}" ;;
      --dry-run) DRY_RUN=1 ;;
      --yes|-y) ASSUME_YES=1 ;;
      --manual) ASSUME_YES=0 ;;
      --no-clean) CLEAN_AFTER=0 ;;
      --deep-clean) DEEP_CLEAN=1 ;;
      --help|-h) print_usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
    esac
    shift || true
  done
}

section() {
  echo
  echo "==== $* ===="
}

update_system() {
  section "System packages" || true
  # Debian/Ubuntu
  if _have apt-get; then
    if confirm "Run apt update && upgrade?"; then
      _sudo_run apt-get update
      _sudo_run apt-get -y upgrade
      _sudo_run apt-get -y autoremove
      _sudo_run apt-get -y autoclean
    else
      echo "Skipped apt"
    fi
  fi

  # Arch
  if _have pacman; then
    local pacman_args="-Syu"
    if [ "$ASSUME_YES" -eq 1 ]; then pacman_args="$pacman_args --noconfirm"; fi
    if confirm "Run pacman $pacman_args?"; then
      _sudo_run pacman $pacman_args
    else
      echo "Skipped pacman"
    fi
  fi

  # AUR helpers
  if _have yay; then
    local yay_args="-Syu"
    if [ "$ASSUME_YES" -eq 1 ]; then yay_args="$yay_args --noconfirm"; fi
    if confirm "Run yay $yay_args?"; then
      _run yay $yay_args
    else
      echo "Skipped yay"
    fi
  fi
  if _have paru; then
    local paru_args="-Syu"
    if [ "$ASSUME_YES" -eq 1 ]; then paru_args="$paru_args --noconfirm"; fi
    if confirm "Run paru $paru_args?"; then
      _run paru $paru_args
    else
      echo "Skipped paru"
    fi
  fi

  # Fedora/RHEL
  if _have dnf; then
    if confirm "Run dnf upgrade -y?"; then
      _sudo_run dnf upgrade -y
      _sudo_run dnf autoremove -y || true
      _sudo_run dnf clean all -y || true
    else
      echo "Skipped dnf"
    fi
  fi

  # openSUSE
  if _have zypper; then
    if confirm "Run zypper refresh && update?"; then
      _sudo_run zypper --non-interactive refresh
      _sudo_run zypper --non-interactive update
    else
      echo "Skipped zypper"
    fi
  fi
}

cleanup_caches() {
  section "Cleanup"

  # Arch pacman cache
  if _have pacman; then
    if _have paccache; then
      # Remove all cached versions (both installed and uninstalled)
      _sudo_run paccache -rk0 || true
      _sudo_run paccache -ruk0 || true
    else
      # Fallback: clear entire cache without prompting
      _sudo_run pacman -Scc --noconfirm || true
    fi
  fi

  # AUR helper build caches
  _run rm -rf "$HOME/.cache/yay" || true
  _run rm -rf "$HOME/.cache/paru" || true
  _run rm -rf "$HOME/.cache/pikaur" || true

  # Flatpak: remove unused runtimes
  if _have flatpak; then
    _run flatpak uninstall --unused -y || true
  fi

  # npm cache
  if _have npm; then
    _run npm cache clean --force || true
  fi

  # pip cache
  if [ -n "$PY3_BIN" ]; then
    _run "$PY3_BIN" -m pip cache purge || true
  fi
}

cleanup_deep() {
  section "Deep Cleanup"

  # Docker: prune everything unused including volumes
  if _have docker; then
    _run docker system prune -af --volumes || true
  fi

  # Systemd journal: vacuum to a time/size threshold
  local journal_for
  journal_for="${CLEAN_JOURNAL_FOR:-7d}"
  if _have journalctl; then
    _sudo_run journalctl --vacuum-time="$journal_for" || _sudo_run journalctl --vacuum-size="$journal_for" || true
  fi

  # Go module cache
  if _have go; then
    _run go clean -modcache || true
  fi

  # Yarn cache
  if _have yarn; then
    _run yarn cache clean || true
  fi

  # Cargo caches via cargo-cache if installed
  if _have cargo-cache; then
    _run cargo cache -a || true
  fi
}

update_flatpak() {
  section "Flatpak"
  if _have flatpak; then
    if confirm "Run flatpak update?"; then
      local args="update"
      if [ "$ASSUME_YES" -eq 1 ]; then args="$args -y"; fi
      _run flatpak $args
    else
      echo "Skipped flatpak"
    fi
  else
    echo "flatpak not installed"
  fi
}

update_snap() {
  section "Snap"
  if _have snap; then
    if confirm "Run snap refresh?"; then
      _sudo_run snap refresh
    else
      echo "Skipped snap"
    fi
  else
    echo "snap not installed"
  fi
}

update_brew() {
  section "Homebrew"
  if _have brew; then
    if confirm "Run brew update/upgrade/cleanup?"; then
      _run brew update
      _run brew upgrade
      _run brew cleanup -s || true
    else
      echo "Skipped brew"
    fi
  else
    echo "brew not installed"
  fi
}

update_nix() {
  section "Nix"
  if _have nix; then
    if confirm "Update Nix profile?"; then
      if _have nix; then _run nix profile upgrade --all || true; fi
      if _have nix-channel; then _run nix-channel --update || true; fi
      if _have nix-env; then _run nix-env -u || true; fi
    else
      echo "Skipped nix"
    fi
  else
    echo "nix not installed"
  fi
}

update_languages() {
  section "Language & dev package managers"
  # pipx first if available
  if _have pipx; then
    if confirm "pipx upgrade --all?"; then
      _run pipx upgrade --all
    else
      echo "Skipped pipx"
    fi
  fi

  # pip user packages (avoid system-wide pip)
  if [ -n "$PY3_BIN" ]; then
    if confirm "Upgrade user pip packages?"; then
      # list outdated and upgrade only those in user site
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "+ $PY3_BIN - <<'PY' ..."
      else
        "$PY3_BIN" - <<'PY'
import subprocess, sys
import json

def sh(cmd):
    return subprocess.check_output(cmd, text=True)

try:
    outdated = json.loads(sh([sys.executable, '-m', 'pip', 'list', '--user', '--outdated', '--format', 'json']))
except Exception:
    outdated = []

for pkg in outdated:
    name = pkg.get('name')
    if not name:
        continue
    print(f"[pip] upgrading {name}...")
    try:
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--user', '--upgrade', name])
    except subprocess.CalledProcessError:
        print(f"[pip] failed to upgrade {name}")
PY
      fi
    else
      echo "Skipped pip user upgrades"
    fi
  fi

  # npm global
  if _have npm; then
    if confirm "npm -g update?"; then
      _run npm -g update || true
      # npm audit fix is invasive; skip by default
    else
      echo "Skipped npm"
    fi
  fi

  # cargo
  if _have cargo; then
    if confirm "cargo install-update all (requires cargo-install-update)?"; then
      if _have cargo-install-update; then
        _run cargo install-update -a
      else
        echo "cargo-install-update not found; skipping"
      fi
    else
      echo "Skipped cargo"
    fi
  fi

  # gem
  if _have gem; then
    if confirm "gem update (user)?"; then
      _run gem update --user-install || true
    else
      echo "Skipped gem"
    fi
  fi
}

update_containers() {
  section "Containers"
  if _have docker; then
    if confirm "Pull newer images for running containers?"; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "+ docker ps --format '{{.Image}}' | xargs -r -n1 docker pull"
      else
        docker ps --format '{{.Image}}' | xargs -r -n1 docker pull
      fi
      echo "Hint: restart containers if needed (not automated)."
    else
      echo "Skipped docker image pulls"
    fi
  else
    echo "docker not installed"
  fi
}

summarize_with_llm() {
  [ "$DO_LLM" -eq 1 ] || { echo "LLM summarization disabled"; return 0; }
  [ "$DRY_RUN" -eq 0 ] || { echo "[DRY-RUN] Would summarize log via LLM"; return 0; }

  section "LLM Summary"
  if [ ! -s "$log_file" ]; then
    echo "No log content to summarize at $log_file"
    return 0
  fi

  # Prepare prompt with truncated log to avoid huge payloads
  # Keep last ~12000 bytes
  local tail_tmp
  tail_tmp="$(mktemp)"
  tail -c 12000 "$log_file" > "$tail_tmp"

  local prompt
  prompt=$(cat <<'PROMPT'
You are a helpful system maintenance assistant. Summarize the following update log succinctly for a power user:

- Key package changes (group by manager)
- Notable warnings or errors
- Follow-up actions recommended (clear steps)
- Any reboots or restarts required

Keep it to ~10 bullet points maximum. If there are errors, put them first under an "Issues" section. Use terse, technical language.

BEGIN LOG SNIPPET
PROMPT
)

  local log_snippet
  log_snippet=$(cat "$tail_tmp")

  local prompt_full
  prompt_full="$prompt
$log_snippet
END LOG SNIPPET"

  # Try Ollama first
  local ollama_url="http://$OLLAMA_HOST:$OLLAMA_PORT/api/generate"
  echo "Attempting Ollama at $ollama_url with model '$MODEL_NAME'"
  local ollama_resp
  set +e
  ollama_resp=$(curl -sS --max-time 10 -H 'Content-Type: application/json' -d @- "$ollama_url" <<EOF
{"model":"$MODEL_NAME","prompt":$(printf %s "$prompt_full" | "$PY3_BIN" -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),"stream":false}
EOF
)
  local ollama_status=$?
  set -e

  local summary_text=""
  if [ $ollama_status -eq 0 ] && echo "$ollama_resp" | grep -q '"response"'; then
    summary_text=$(echo "$ollama_resp" | "$PY3_BIN" -c 'import sys,json; print(json.load(sys.stdin).get("response",""))')
    echo "$summary_text" | tee "$summary_file" >/dev/null
    echo "Summary saved to: $summary_file"
    rm -f "$tail_tmp"
    return 0
  fi

  # Next: text-generation-webui (remote)
  local tgw_base="http://$TGEN_HOST:$TGEN_PORT"
  local tgw_openai_url="$tgw_base/v1/chat/completions"
  echo "Trying text-generation-webui (OpenAI compat) at $tgw_openai_url"
  local tgw_payload
  tgw_payload=$("$PY3_BIN" - <<'PY'
import json, os
model = os.environ.get('MODEL_NAME','llama3.1')
prompt_full = os.environ.get('PROMPT_FULL','')
body = {
    "model": model,
    "messages": [
        {"role":"system","content":"You are a helpful system maintenance assistant."},
        {"role":"user","content": prompt_full},
    ],
    "temperature": 0.2
}
print(json.dumps(body))
PY
)
  local tgw_resp
  set +e
  MODEL_NAME="$MODEL_NAME" PROMPT_FULL="$prompt_full" tgw_resp=$(
    printf %s "$tgw_payload" | curl -sS --max-time 10 -H 'Content-Type: application/json' --data-binary @- "$tgw_openai_url"
  )
  local tgw_status=$?
  set -e
  if [ $tgw_status -eq 0 ] && echo "$tgw_resp" | grep -q '"choices"'; then
    summary_text=$(echo "$tgw_resp" | "$PY3_BIN" - <<'PY'
import sys, json
data = json.load(sys.stdin)
choices = data.get('choices') or []
if choices:
    msg = choices[0].get('message') or {}
    print(msg.get('content',''))
PY
)
    echo "$summary_text" | tee "$summary_file" >/dev/null
    echo "Summary saved to: $summary_file"
    rm -f "$tail_tmp"
    return 0
  fi

  # Try native text-generation-webui API (/api/v1/generate)
  local tgw_native_url="$tgw_base/api/v1/generate"
  echo "Trying text-generation-webui native API at $tgw_native_url"
  local tgw_native_payload
  tgw_native_payload=$("$PY3_BIN" - <<'PY'
import json, os
prompt_full = os.environ.get('PROMPT_FULL','')
body = {
    "prompt": prompt_full,
    "max_new_tokens": 256,
    "temperature": 0.2,
    "stop": ["</s>"]
}
print(json.dumps(body))
PY
)
  set +e
  PROMPT_FULL="$prompt_full" tgw_resp=$(
    printf %s "$tgw_native_payload" | curl -sS --max-time 10 -H 'Content-Type: application/json' --data-binary @- "$tgw_native_url"
  )
  tgw_status=$?
  set -e
  if [ $tgw_status -eq 0 ] && echo "$tgw_resp" | grep -q '"results"'; then
    summary_text=$(echo "$tgw_resp" | "$PY3_BIN" - <<'PY'
import sys, json
data = json.load(sys.stdin)
res = data.get('results') or []
if res:
    print(res[0].get('text',''))
PY
)
    echo "$summary_text" | tee "$summary_file" >/dev/null
    echo "Summary saved to: $summary_file"
    rm -f "$tail_tmp"
    return 0
  fi

  # Fallback to LocalAI (OpenAI-compatible)
  local localai_base="$LOCALAI_URL"
  local localai_url="$localai_base/v1/chat/completions"
  echo "Falling back to LocalAI at $localai_url with model '$MODEL_NAME'"

  # Optional: check if any models are available to avoid noisy 500s
  set +e
  local models_json
  models_json=$(curl -sS --max-time 5 "$localai_base/v1/models")
  local models_check=$?
  set -e
  if [ $models_check -eq 0 ] && echo "$models_json" | grep -q '"data"'; then
    local have_model
    have_model=$(echo "$models_json" | "$PY3_BIN" - "$MODEL_NAME" <<'PY'
import sys, json
data = json.load(sys.stdin)
target = sys.argv[1]
ids = [m.get('id') for m in (data.get('data') or [])]
print('yes' if target in ids else ('any' if ids else 'no'))
PY
)
    if [ "$have_model" = "no" ]; then
      echo "LocalAI reports no models; skipping summarization."
      rm -f "$tail_tmp"
      return 0
    fi
  fi

  local payload
  payload=$("$PY3_BIN" - <<'PY'
import json, sys, os
model = os.environ.get('MODEL_NAME','llama3.1')
prompt_full = os.environ.get('PROMPT_FULL','')
body = {
    "model": model,
    "messages": [
        {"role":"system","content":"You are a helpful system maintenance assistant."},
        {"role":"user","content": prompt_full},
    ],
    "temperature": 0.2
}
print(json.dumps(body))
PY
)
  local localai_resp
  set +e
  MODEL_NAME="$MODEL_NAME" PROMPT_FULL="$prompt_full" localai_resp=$(
    printf %s "$payload" | curl -sS --max-time 15 -H 'Content-Type: application/json' --data-binary @- "$localai_url"
  )
  local localai_status=$?
  set -e
  if [ $localai_status -eq 0 ] && echo "$localai_resp" | grep -q '"choices"'; then
    summary_text=$(echo "$localai_resp" | "$PY3_BIN" - <<'PY'
import sys, json
data = json.load(sys.stdin)
choices = data.get('choices') or []
if choices:
    msg = choices[0].get('message') or {}
    print(msg.get('content',''))
PY
)
    echo "$summary_text" | tee "$summary_file" >/dev/null
    echo "Summary saved to: $summary_file"
  else
    echo "LLM summarization failed (both endpoints)."
  fi
  rm -f "$tail_tmp"
}

main() {
  parse_args "$@"
  ensure_log_setup

  echo "Started: $(date -Is)"
  echo "Host: $(hostname) | User: $(whoami)"
  echo "Flags: system=$DO_SYSTEM flatpak=$DO_FLATPAK snap=$DO_SNAP brew=$DO_BREW nix=$DO_NIX lang=$DO_LANG containers=$DO_CONTAINERS dry_run=$DRY_RUN yes=$ASSUME_YES clean=$CLEAN_AFTER deep=$DEEP_CLEAN llm=$DO_LLM model=$MODEL_NAME"

  if [ "$DO_SYSTEM" -eq 1 ]; then update_system; fi
  if [ "$DO_FLATPAK" -eq 1 ]; then update_flatpak; fi
  if [ "$DO_SNAP" -eq 1 ]; then update_snap; fi
  if [ "$DO_BREW" -eq 1 ]; then update_brew; fi
  if [ "$DO_NIX" -eq 1 ]; then update_nix; fi
  if [ "$DO_LANG" -eq 1 ]; then update_languages; fi
  if [ "$DO_CONTAINERS" -eq 1 ]; then update_containers; fi

  echo "Finished updates: $(date -Is)"

  if [ "$CLEAN_AFTER" -eq 1 ]; then
    cleanup_caches
    if [ "$DEEP_CLEAN" -eq 1 ]; then
      cleanup_deep
    fi
  fi

  summarize_with_llm

  if [ "$DRY_RUN" -eq 0 ]; then
    echo "Full log: $log_file"
    [ -s "$summary_file" ] && echo "LLM summary: $summary_file"
  fi
}

main "$@"
