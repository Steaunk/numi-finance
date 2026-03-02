# Expense Tracker

A multi-currency expense tracking web app built with Django and SQLite.

Supports CNY, HKD, USD, SGD with daily exchange rates from [fawazahmed0/currency-api](https://github.com/fawazahmed0/currency-api).

## Features

- Add expenses via web form or bulk JSON import
- Automatic exchange rate fetching (cached daily)
- Convert and display all amounts in a selected currency
- Monthly bar chart and category breakdown doughnut chart

## Quick Start

### Docker

```bash
# Production (uwsgi)
docker compose up --build

# Development (django runserver + hot reload)
docker compose -f docker-compose.dev.yml up --build
```

### Local

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

Open http://localhost:8000

## Bulk Import Format

```json
[
  {"amount": 50, "currency": "USD", "date": "2026-03-01", "category": "Food", "name": "Lunch", "notes": ""},
  {"amount": 200, "currency": "HKD", "date": "2026-03-02", "category": "Transport", "name": "Taxi", "notes": ""}
]
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | `false` | Enable Django debug mode |
| `DATABASE_PATH` | `db.sqlite3` | SQLite database file path |
| `ALLOWED_HOSTS` | `*` | Comma-separated allowed hosts |
