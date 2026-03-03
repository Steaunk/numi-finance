#!/bin/bash
set -e

DB="/app/data/db.sqlite3"
REMOTE="qiniu:${QINIU_BUCKET}"
DATE=$(date +%Y%m%d_%H%M%S)

echo "[$(date)] Starting backup..."

rclone copy "$DB" "${REMOTE}/db_${DATE}.sqlite3"

# Keep only the latest 30 backups
COUNT=$(rclone ls "${REMOTE}/" | wc -l)
if [ "$COUNT" -gt 30 ]; then
    EXCESS=$((COUNT - 30))
    rclone ls "${REMOTE}/" | sort | head -n "$EXCESS" | awk '{print $2}' | \
        xargs -I{} rclone deletefile "${REMOTE}/{}"
    echo "[$(date)] Removed $EXCESS old backup(s)"
fi

echo "[$(date)] Backup complete: db_${DATE}.sqlite3"
