#!/usr/bin/env bash
# rsa-update-dietpi.sh
# Updates RSAssistant on the DietPi server cleanly and safely.
source ~/.ssh/auto_ssh_agent.sh
set -euo pipefail

REMOTE_USER="braydenchaffee"
REMOTE_HOST="192.168.1.198"
REMOTE_CMD=$(
  cat <<'EOF'
ssh-add ~/.ssh/github-braydio
cd ~/RSAssistant
echo "[RSAssistant] Stopping service..."
sudo systemctl stop dietpi-autostart_rsassistant
echo "[RSAssistant] Pulling latest changes..."
git pull
echo "[RSAssistant] Restarting service..."
sudo systemctl restart dietpi-autostart_rsassistant
echo "[RSAssistant] Done."
EOF
)

ssh "${REMOTE_USER}@${REMOTE_HOST}" "$REMOTE_CMD"
