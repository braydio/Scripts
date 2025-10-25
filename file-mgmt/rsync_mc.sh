#!/usr/bin/env bash
# Sync Minecraft mods from Arch server to mounted Windows mods folder
# Obeys .gitignore and auto-mounts if needed.

SRC="$HOME/Projects/VRCraft/Minecraft/mods"
DEST="/mnt/Data/Minecraft"

# Auto-mount if not already mounted
if ! mountpoint -q "$DEST"; then
  echo "Mounting $DEST..."
  sudo mount "$DEST" || {
    echo "Failed to mount $DEST"
    exit 1
  }
fi

# Verify destination exists
if [ ! -d "$DEST" ]; then
  echo "Destination $DEST not found or not mounted."
  exit 1
fi

# Temporary exclude list
TMP_EXCLUDES=$(mktemp)

# Use .gitignore to exclude files if it exists
if [ -f "$SRC/.gitignore" ]; then
  echo "Applying .gitignore rules..."
  git -C "$SRC" check-ignore -v --stdin <"$SRC/.gitignore" | awk '{print $3}' >"$TMP_EXCLUDES"
fi

# Perform sync
echo "Syncing mods from $SRC to $DEST ..."
rsync -avz --delete --exclude-from="$TMP_EXCLUDES" "$SRC"/ "$DEST"/

# Cleanup
rm -f "$TMP_EXCLUDES"
echo "Sync complete."
