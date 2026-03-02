FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpcre3-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

VOLUME /app/data

ENV DATABASE_PATH=/app/data/db.sqlite3

CMD python manage.py migrate --run-syncdb && \
    uwsgi --socket :8000 --module config.wsgi --master --processes 2 --threads 2
