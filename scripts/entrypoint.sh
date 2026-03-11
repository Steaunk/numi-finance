#!/bin/bash
set -e

CRON_JOBS=""

# Daily API account sync + snapshot at 1am UTC (9am SGT)
CRON_JOBS="0 1 * * * cd /app && DATABASE_PATH=${DATABASE_PATH} DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY} python manage.py sync_api_accounts >> /var/log/sync_api.log 2>&1"

# Setup rclone + backup cron if Qiniu credentials are provided
if [ -n "$QINIU_ACCESS_KEY" ] && [ -n "$QINIU_SECRET_KEY" ] && [ -n "$QINIU_BUCKET" ]; then
    mkdir -p /root/.config/rclone
    cat > /root/.config/rclone/rclone.conf << EOF
[qiniu]
type = s3
provider = Qiniu
access_key_id = ${QINIU_ACCESS_KEY}
secret_access_key = ${QINIU_SECRET_KEY}
endpoint = ${QINIU_ENDPOINT:-s3-cn-east-1.qiniucs.com}
EOF
    CRON_JOBS="${CRON_JOBS}
0 2 * * * /app/scripts/backup.sh >> /var/log/backup.log 2>&1"
    echo "[entrypoint] Backup cron configured (daily 2am UTC)"
else
    echo "[entrypoint] Qiniu credentials not set, skipping backup setup"
fi

echo "$CRON_JOBS" | crontab -
service cron start
echo "[entrypoint] API account sync cron configured (daily 1am UTC / 9am SGT)"

python manage.py migrate --run-syncdb

exec uwsgi --socket :8000 --module config.wsgi --master --processes 2 --threads 2
