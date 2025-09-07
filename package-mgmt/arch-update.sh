#!/usr/bin/env bash
# File: ~/Scripts/arch-update.sh
# Purpose: One-shot Arch + AUR update and cleanup with no confirmations.
# Notes: Configure sudoers for passwordless pacman/yay if you want zero prompts.
#   youruser ALL=(ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/yay, /usr/bin/paru, /usr/bin/journalctl, /usr/bin/paccache

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Config ────────────────────────────────────────────────────────────────────
AUR_HELPER="yay"       # "yay" or "paru" (auto-detected if empty)
NONINTERACTIVE=true    # true = never prompt
KEEP_PACMAN_VERSIONS=3 # paccache keep N versions
VACUUM_JOURNAL="7d"    # journalctl --vacuum-time value

CLEAN_AUR_CACHE=true
CLEAN_JOURNAL_LOGS=true
CLEAN_USER_CACHE=true

ENABLE_LOGGING=true
LOG_DIR="$HOME/.local/var/update-arch"

# ─── Utils ─────────────────────────────────────────────────────────────────────
header() { printf "\n\e[1;36m==> %s\e[0m\n" "$1"; }
warn() { printf "\e[33m[warn]\e[0m %s\n" "$1"; }
err() { printf "\e[31m[err ]\e[0m %s\n" "$1"; }

die() {
  err "$1"
  exit 1
}

# Essential commands check (why: fail early with clear guidance)
need() { command -v "$1" &>/dev/null || die "Missing '$1'. Install it first."; }

# Logging setup (why: persist what changed for audits)
setup_logging() {
  $ENABLE_LOGGING || return 0
  mkdir -p "$LOG_DIR"
  local stamp
  stamp=$(date +"%Y-%m-%d_%H-%M-%S")
  LOG_FILE="$LOG_DIR/$stamp.log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  header "Logging to $LOG_FILE"
}

# Internet check (why: avoid sync failures due to no network)
have_internet() { ping -c1 -W1 archlinux.org &>/dev/null || return 1; }

# Orphans removal (safe handling of empty list)
remove_orphans() {
  header "Removing orphaned packages..."
  # Prefer -Qtd (true orphans), fallback to -Qdt if older pacman
  local q
  if ! q=$(pacman -Qtdq 2>/dev/null || true); then q=$(pacman -Qdtq 2>/dev/null || true); fi
  if [[ -n "$q" ]]; then
    sudo pacman -Rns --noconfirm $q
  else
    echo "No orphans found."
  fi
}

# AUR cache cleanup based on helper
clean_aur_cache() {
  $CLEAN_AUR_CACHE || return 0
  header "Cleaning AUR helper cache..."
  case "$AUR_HELPER" in
  yay) yay -Scc --noconfirm || true ;;
  paru) paru -Scc --noconfirm || true ;;
  *) warn "Unsupported AUR helper: $AUR_HELPER" ;;
  esac
}

# ─── Main Steps ────────────────────────────────────────────────────────────────
main() {
  setup_logging

  # Discover AUR helper if unset
  if [[ -z "${AUR_HELPER:-}" ]]; then
    if command -v yay &>/dev/null; then
      AUR_HELPER=yay
    elif command -v paru &>/dev/null; then
      AUR_HELPER=paru
    else
      warn "No AUR helper found; AUR updates will be skipped."
      AUR_HELPER=""
    fi
  fi

  # Requirements
  need sudo
  need pacman
  need paccache
  need journalctl
  [[ -n "$AUR_HELPER" ]] && need "$AUR_HELPER"

  # Cache sudo token (why: avoid mid-run prompts)
  sudo -v || true

  header "Connectivity check"
  if ! have_internet; then
    warn "No internet connectivity detected; proceeding may fail."
  else
    echo "Online."
  fi

  header "Synchronizing and updating system packages (pacman)"
  # --noconfirm: no prompts; --needed not used for -Syu
  sudo pacman -Syu --noconfirm

  if [[ -n "$AUR_HELPER" ]]; then
    header "Updating AUR packages ($AUR_HELPER)"
    "$AUR_HELPER" -Syu --needed --noconfirm
  fi

  header "Cleaning pacman cache (keeping $KEEP_PACMAN_VERSIONS versions)"
  # -r removes old, -k keep N
  sudo paccache -rk "$KEEP_PACMAN_VERSIONS" || sudo paccache -r || true

  remove_orphans
  clean_aur_cache

  if $CLEAN_JOURNAL_LOGS; then
    header "Cleaning journal logs (older than $VACUUM_JOURNAL)"
    sudo journalctl --vacuum-time="$VACUUM_JOURNAL" || true
  fi

  header "Cleaning pip cache"
  (command -v pip &>/dev/null && pip cache purge) || true

  header "Cleaning npm cache"
  (command -v npm &>/dev/null && npm cache clean --force) || true

  header "Cleaning yarn cache"
  (command -v yarn &>/dev/null && yarn cache clean) || true

  header "Cleaning nvm cache"
  if [[ -s "$HOME/.nvm/nvm.sh" ]] || command -v nvm &>/dev/null; then
    # shellcheck disable=SC1090
    [[ -s "$HOME/.nvm/nvm.sh" ]] && source "$HOME/.nvm/nvm.sh"
    nvm cache clear || true
  fi

  header "Cleaning Cargo build cache"
  if command -v cargo-cache &>/dev/null; then
    cargo cache --autoclean || true
  else
    echo "Tip: Install cargo-cache → cargo install cargo-cache"
  fi

  header "Cleaning Cypress cache"
  rm -rf "$HOME/.cache/Cypress" || true

  header "Cleaning Mozilla cache"
  rm -rf "$HOME/.cache/mozilla" "$HOME"/.mozilla/firefox/*.default*/cache2 || true

  if $CLEAN_USER_CACHE; then
    header "Cleaning user cache (~/.cache)"
    rm -rf "$HOME/.cache"/* || true
  fi

  header "Disk usage by mount point"
  df -hT | grep -v tmpfs | grep -v "/mnt" || true

  header "Top 10 largest paths in / (excluding /proc, /sys, /mnt)"
  sudo du -ahx / --exclude=/proc --exclude=/sys --exclude=/mnt 2>/dev/null | sort -rh | head -n 10 || true

  header "Package counts"
  total=$(pacman -Q | wc -l | tr -d ' ')
  explicit=$(pacman -Qe | wc -l | tr -d ' ')
  echo "  Total packages:        $total"
  echo "  Explicitly installed:  $explicit"

  if command -v ncdu &>/dev/null; then
    if [[ "$NONINTERACTIVE" != true ]]; then
      header "Launch ncdu for manual inspection?"
      read -r -p "Launch ncdu? (y/n): " launch || true
      [[ $launch == [Yy]* ]] && sudo ncdu / --exclude /mnt
    else
      echo "ncdu available; skipping launch due to NONINTERACTIVE=true"
    fi
  else
    echo "Tip: Install ncdu → sudo pacman -S ncdu"
  fi

  header "✅ Update & cleanup complete. Reboot recommended if kernel or key libraries were updated."
}

main "$@"
