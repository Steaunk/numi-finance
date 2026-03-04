# Numi Finance

A multi-currency personal finance app with a Django backend and Flutter (Android / macOS) frontend.

Tracks expenses, travel trips, and asset accounts across CNY, HKD, USD, SGD, and JPY with daily exchange rates from [fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api).

## Features

### Expenses
- Add/edit/delete expenses with 10 categories
- Monthly totals and category breakdown charts
- Bulk JSON import
- Pre-computed multi-currency amounts for fast display

### Travel
- Create trips with destination, dates, and notes
- Track per-trip expenses (Transportation, Accommodation, Sightseeing, Food & Drinks, Shopping, Other)

### Assets
- Manage accounts in different currencies
- Net worth calculation across all accounts
- Historical balance snapshots and trend charts
- FIRE progress tracker (configurable withdrawal rate, runway estimate)
- 17 auto-matched account icons served from the backend (banks, brokers, wallets, crypto, etc.)

### Mobile & Desktop App (Flutter)
- Android APK and macOS DMG builds
- Offline-first with local SQLite (Drift) database
- Background sync with Django backend when online
- In-app auto-update via GitHub Releases
- Display amounts in any supported currency
- Consistent category colors across chart views

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

### Flutter App

```bash
cd numi_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Android
flutter build apk --release

# macOS
flutter build macos --release
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/rates/` | Current exchange rates |
| GET | `/api/geo/currency/` | Detect currency by geolocation |
| GET/POST | `/api/expenses/` | List / add expenses |
| DELETE | `/api/expenses/<id>/` | Delete expense |
| POST | `/api/expenses/import/` | Bulk JSON import |
| GET | `/api/expenses/monthly-stats/` | Monthly statistics |
| GET | `/api/expenses/categories/` | Expense categories |
| GET/POST | `/api/travel/trips/` | List / add trips |
| GET/PUT/DELETE | `/api/travel/trips/<id>/` | Trip detail |
| GET/POST | `/api/travel/trips/<id>/expenses/` | Trip expenses |
| DELETE | `/api/travel/expenses/<id>/` | Delete trip expense |
| GET/POST | `/api/accounts/` | List / add accounts |
| PUT/DELETE | `/api/accounts/<id>/` | Update / delete account |
| GET | `/api/accounts/net-worth/` | Net worth summary |
| GET | `/api/accounts/trends/` | Historical balance trends |
| GET | `/api/account-icons/` | Account icon mappings + SVGs (versioned) |

## Bulk Import Format

```json
[
  {"amount": 50, "currency": "USD", "date": "2026-03-01", "category": "Food & Drinks", "name": "Lunch", "notes": ""},
  {"amount": 200, "currency": "HKD", "date": "2026-03-02", "category": "Transport", "name": "Taxi", "notes": ""}
]
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DJANGO_SECRET_KEY` | dev placeholder | Django secret key (set in production) |
| `DEBUG` | `true` | Enable Django debug mode |
| `DATABASE_PATH` | `db.sqlite3` | SQLite database file path |
| `ALLOWED_HOSTS` | `*` | Comma-separated allowed hosts |

## CI/CD

GitHub Actions builds the Flutter APK on every push to `main` that changes `numi_app/`. macOS DMG builds can be triggered manually via `workflow_dispatch` with the `build_macos` input. Each build creates a GitHub Release tagged `vYYYYMMDD.N` (date + daily sequence) with artifacts attached. The mobile/desktop app checks for updates on launch via the GitHub Releases API. Concurrent runs on the same branch are auto-cancelled.
