#!/bin/bash

REMOTE="user@remote_server"

echo "Syncing scripts..."
rsync -avz ~/scripts/ "$REMOTE:~/scripts/"

echo "Syncing bash aliases..."
rsync -avz ~/.bash_aliases "$REMOTE:~/"

echo "Sync complete."
