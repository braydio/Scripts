#!/usr/bin/env bash
# Arch update entrypoint
#
# Behavior:
# - Delegates to the unified updater without forcing extra flags.
# - By default, performs a non-interactive system upgrade (pacman + yay/paru if present)
#   and cleans caches. Pass --manual to require confirmations, or --no-clean to skip cleanup.
#
# Examples:
#   ./package-mgmt/arch-update.sh            # non-interactive + cleanup (default)
#   ./package-mgmt/arch-update.sh --manual   # interactive confirmations
#   ./package-mgmt/arch-update.sh --flatpak  # include Flatpak updates
#   ./package-mgmt/arch-update.sh --no-clean # skip cache cleanup

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
updater="$script_dir/update-all.sh"

if [ ! -x "$updater" ]; then
  echo "Missing updater at $updater; make sure it's present and executable." >&2
  exit 1
fi

# Do not inject defaults here; let update-all.sh defaults apply.
exec "$updater" "$@"
