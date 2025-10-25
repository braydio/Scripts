#!/usr/bin/env bash
# System cleanup & overview (safe defaults)
# - Keeps more pacman pkg versions for easier downgrades
# - Confirms orphan removals
# - Retains 14d of journal logs (tweakable)
# - Avoids nuking all ~/.cache blindly
# - Skips massive mounts in size scans

set -o errexit
set -o nounset
set -o pipefail

# ─── Config ───────────────────────────────────────────────
CLEAN_AUR_CACHE=true      # true|false — clean yay/paru caches
CLEAN_JOURNAL_LOGS=true   # true|false — vacuum journal logs
AUR_HELPER="yay"          # yay|paru|other (unsupported prints a tip)
PACMAN_KEEP_VERSIONS=5    # pacman cache packages to keep per pkg
JOURNAL_RETENTION_DAYS=14 # journalctl --vacuum-time
ASK_BEFORE_REMOVING_ORPHANS=true

# Directories to exclude from the "largest folders" scan
EXCLUDE_DIRS=(/proc /sys /run /dev /var/lib/docker /mnt /media /srv)

# ─── Utilities ────────────────────────────────────────────
print_header() { echo -e "\n\033[1;36m==> $1\033[0m"; }
have() { command -v "$1" &>/dev/null; }

confirm() {
  local prompt="${1:-Proceed? (y/N): }"
  read -r -p "$prompt" ans || true
  [[ "$ans" =~ ^[Yy] ]]
}

# ─── Pacman Cache ─────────────────────────────────────────
if have paccache; then
  print_header "Cleaning pacman cache (keeping $PACMAN_KEEP_VERSIONS versions per package)..."
  sudo paccache -rk "$PACMAN_KEEP_VERSIONS"
else
  print_header "Skipping pacman cache clean (paccache not found). Tip: sudo pacman -S pacman-contrib"
fi

# ─── Orphaned Packages ────────────────────────────────────
print_header "Checking orphaned packages..."
orphans="$(pacman -Qdtq || true)"
if [[ -n "${orphans}" ]]; then
  echo "Orphans detected:"
  echo "$orphans" | sed 's/^/  - /'
  if $ASK_BEFORE_REMOVING_ORPHANS; then
    if confirm "Remove these orphans with 'pacman -Rns'? (y/N): "; then
      sudo pacman -Rns -- $orphans
    else
      echo "Skipped orphan removal."
    fi
  else
    sudo pacman -Rns -- $orphans
  fi
else
  echo "No orphans found."
fi

# ─── AUR Helper Cache ─────────────────────────────────────
if $CLEAN_AUR_CACHE; then
  print_header "Cleaning AUR helper cache..."
  case "$AUR_HELPER" in
  yay)
    if have yay; then yay -Sc --noconfirm; else echo "Tip: install yay or set AUR_HELPER accordingly."; fi
    ;;
  paru)
    if have paru; then paru -Sc --noconfirm; else echo "Tip: install paru or set AUR_HELPER accordingly."; fi
    ;;
  *)
    echo "Unsupported AUR helper: $AUR_HELPER (skipping)."
    ;;
  esac
fi

# ─── Journal Logs ─────────────────────────────────────────
if $CLEAN_JOURNAL_LOGS; then
  print_header "Cleaning journal logs (older than ${JOURNAL_RETENTION_DAYS} days)..."
  sudo journalctl --vacuum-time="${JOURNAL_RETENTION_DAYS}d"
fi

# ─── Toolchain & App Caches ───────────────────────────────
print_header "Cleaning pip cache..."
# Use python -m pip if present; otherwise fall back
if have python && python -m pip --version &>/dev/null; then
  python -m pip cache purge || true
elif have pip; then
  pip cache purge || true
fi

print_header "Cleaning npm cache..."
if have npm; then npm cache clean --force || true; fi

print_header "Cleaning yarn cache..."
if have yarn; then yarn cache clean || true; fi

print_header "Cleaning nvm (Node Version Manager) cache..."
if have nvm; then nvm cache clear || true; fi

print_header "Cleaning Cargo (Rust) build cache..."
if have cargo-cache; then
  cargo cache --autoclean || true
else
  echo "Tip: Install cargo-cache → cargo install cargo-cache"
fi

print_header "Cleaning Cypress cache..."
rm -rf "${HOME}/.cache/Cypress" || true

print_header "Cleaning Mozilla caches (safe-only; keeps profiles)..."
# Avoid deleting ~/.mozilla profiles; only clear caches
rm -rf "${HOME}/.cache/mozilla" || true
# Clear per-profile Firefox cache2 safely if present
shopt -s nullglob
for p in "${HOME}"/.mozilla/firefox/*.default*; do
  rm -rf "${p}/cache2" || true
done
shopt -u nullglob

print_header "Cleaning selective user caches (~/.cache)..."
# Avoid blanket wipe to prevent needless re-index / logouts.
# Keep some dirs; remove everything else at top-level of ~/.cache
SAFE_KEEP=(fontconfig thumbnails)
find "${HOME}/.cache" -mindepth 1 -maxdepth 1 \
  $(printf '! -name %q ' "${SAFE_KEEP[@]}") \
  -exec rm -rf {} + 2>/dev/null || true

# ─── System Usage Overview ────────────────────────────────
print_header "Disk usage by mount point:"
df -hT | awk 'NR==1 || $2!="tmpfs"'

print_header "Top 10 largest folders under / (excluding heavy/ephemeral mounts):"
# Build exclude args for du
EXCLUDE_ARGS=()
for d in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$d")
done
# Use -x to stay on one filesystem (root). Combine with excludes for common heavy mounts.
sudo du -xhd1 / "${EXCLUDE_ARGS[@]}" 2>/dev/null | sort -hr | head -n 10

print_header "Package count:"
total="$(pacman -Q | wc -l)"
explicit="$(pacman -Qe | wc -l)"
echo "  Total packages:          ${total}"
echo "  Explicitly installed:    ${explicit}"

# ─── Optional ncdu Launcher ───────────────────────────────
if have ncdu; then
  print_header "Launch ncdu for manual inspection?"
  if confirm "Launch ncdu on / ? (y/N): "; then
    sudo ncdu /
  else
    echo "Skipped ncdu."
  fi
else
  echo -e "\nTip: Install ncdu → sudo pacman -S ncdu"
fi

print_header "✅ System cleanup complete."
