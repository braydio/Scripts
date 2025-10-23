#!/bin/bash
# sshh.sh - connect to local devices via SSH using stored credentials.
#
# Usage:
#   sshh.sh [--config] <target>
#
# With --config, opens the configuration file in nvim for editing.

set -euo pipefail

CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/ssh_hosts.conf"
USER="braydenchaffee"
PASSWORD="0323"

usage() {
  echo "Usage: $0 [--config] <target>"
  echo "Available targets are defined in $CONFIG_FILE"
}

if [[ ${1-} == "--config" ]]; then
  nvim "$CONFIG_FILE"
  exit 0
fi

TARGET=${1-}
if [[ -z "$TARGET" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

IP="${!TARGET:-}"
if [[ -z "$IP" ]]; then
  echo "Unknown target: $TARGET" >&2
  exit 1
fi

sshpass -p "$PASSWORD" ssh "$USER@$IP"
