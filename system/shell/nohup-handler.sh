#!/bin/bash
LOGDIR="$HOME/nohup_logs"
mkdir -p "$LOGDIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
nohup "$@" > "$LOGDIR/nohup_$TIMESTAMP.log" 2>&1 &
echo "Log: $LOGDIR/nohup_$TIMESTAMP.log" &
