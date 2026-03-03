#!/bin/bash
set -e

# Setup rclone + cron if Qiniu credentials are provided
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
    echo "0 2 * * * /app/scripts/backup.sh >> /var/log/backup.log 2>&1" | crontab -
    service cron start
    echo "[entrypoint] Backup cron job configured (daily 2am)"
else
    echo "[entrypoint] Qiniu credentials not set, skipping backup setup"
fi

python manage.py migrate --run-syncdb

exec uwsgi --socket :8000 --module config.wsgi --master --processes 2 --threads 2
