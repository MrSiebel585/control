#!/bin/bash

# Define hosts and paths
REMOTE1="jeremy@engram"
REMOTE2="jeremy@aspire"
DIR="/opt/omniscient"
LOG="/opt/omniscient/logs/rsync_sync.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log directory exists
mkdir -p "$(dirname "$LOG")"

echo "==== Sync started at $TIMESTAMP ====" >> "$LOG"

# Step 1: Rsync from REMOTE1 to REMOTE2
echo "[1] Syncing from $REMOTE1 to $REMOTE2..." | tee -a "$LOG"
ssh $REMOTE1 "rsync -avz --delete --update $DIR/ $REMOTE2:$DIR" >> "$LOG" 2>&1

# Step 2: Rsync from REMOTE2 to REMOTE1
echo "[2] Syncing from $REMOTE2 to $REMOTE1..." | tee -a "$LOG"
ssh $REMOTE2 "rsync -avz --delete --update $DIR/ $REMOTE1:$DIR" >> "$LOG" 2>&1

echo "[✓] Sync complete." | tee -a "$LOG"

