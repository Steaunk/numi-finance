FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpcre2-dev cron curl unzip && \
    curl -L https://downloads.rclone.org/rclone-current-linux-amd64.zip -o /tmp/rclone.zip && \
    unzip /tmp/rclone.zip -d /tmp && \
    mv /tmp/rclone-*-linux-amd64/rclone /usr/local/bin/ && \
    rm -rf /tmp/rclone* /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

VOLUME /app/data

ENV DATABASE_PATH=/app/data/db.sqlite3

RUN chmod +x /app/scripts/entrypoint.sh

CMD ["/app/scripts/entrypoint.sh"]
