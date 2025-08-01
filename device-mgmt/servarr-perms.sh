#!/bin/bash

MEDIA_PATH="/mnt/netstorage/Media"
MEDIA_GROUP="media"

echo "?? Fixing media directory permissions on Arch Host..."
echo "?? Target path: $MEDIA_PATH"

# Ensure media group exists
if ! getent group "$MEDIA_GROUP" >/dev/null; then
  echo "? Creating group: $MEDIA_GROUP"
  sudo groupadd "$MEDIA_GROUP"
fi

# Set group ownership and perms
echo "?? Setting ownership to media:media recursively..."
sudo chown -R $MEDIA_GROUP:$MEDIA_GROUP "$MEDIA_PATH"

echo "?? Setting directory permissions to 775 (rwxrwxr-x)..."
sudo find "$MEDIA_PATH" -type d -exec chmod 775 {} \;

echo "?? Setting file permissions to 664 (rw-rw-r--)..."
sudo find "$MEDIA_PATH" -type f -exec chmod 664 {} \;

echo "? Media permissions fixed on host."
