# Numi Finance

A multi-currency personal finance app with a Django backend and Flutter (Android / macOS) frontend.

Tracks expenses, travel trips, asset accounts, and investment portfolios across CNY, HKD, USD, SGD, and JPY with daily exchange rates from [fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api).

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
- Transfer funds between accounts (with automatic currency conversion)
- Net worth calculation across all accounts
- Historical balance snapshots and trend charts
- API-synced accounts: backend auto-fetches balances from external sources via configurable API URL + JSON path
- Daily cron job for balance snapshots; app-triggered sync also snapshots if >12h stale
- FIRE progress tracker (configurable withdrawal rate, runway estimate)
- 17 auto-matched account icons served from the backend (banks, brokers, wallets, crypto, etc.)

### Portfolio
- Stock holdings, portfolio history, and per-stock history charts (proxied from a configurable upstream data service)
- Fund, bond, and cash positions from broker account data
- Background cache refresh with stale-while-revalidate pattern

### Mobile & Desktop App (Flutter)
- Android APK and macOS DMG builds
- Offline-first with local SQLite (Drift) database
- Sync queue for offline mutations — automatically retried when back online
- Background sync with Django backend when online
- In-app auto-update via GitHub Releases
- Display amounts in any supported currency
- Biometric lock screen

## Quick Start

### Docker

```bash
# Production (uwsgi + cron)
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

# Android
flutter build apk --release

# macOS
flutter build macos --release
```

## API Endpoints

### Core
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/rates/` | Current exchange rates |
| GET | `/api/geo/currency/` | Detect currency by geolocation |
| GET | `/api/account-icons/` | Account icon mappings + SVGs (versioned) |

### Expenses (`/expenses/`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/expenses/` | List expenses (by month) |
| POST | `api/expenses/add/` | Add expense |
| POST | `api/expenses/bulk/` | Bulk JSON import |
| PUT/DELETE | `api/expenses/<id>/` | Update / delete expense |
| GET | `api/categories/` | Expense categories |
| GET | `api/stats/monthly/` | Monthly statistics |

### Travel (`/expenses/`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/travel/trips/` | List trips |
| POST | `api/travel/trips/add/` | Add trip |
| PUT | `api/travel/trips/<id>/` | Update trip |
| DELETE | `api/travel/trips/<id>/delete/` | Delete trip |
| GET | `api/travel/trips/<id>/expenses/` | List trip expenses |
| POST | `api/travel/trips/<id>/expenses/add/` | Add trip expense |
| PUT | `api/travel/trips/<id>/expenses/<eid>/` | Update trip expense |
| DELETE | `api/travel/trips/<id>/expenses/<eid>/delete/` | Delete trip expense |

### Assets (`/assets/`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/accounts/` | List accounts with converted balances |
| POST | `api/accounts/add/` | Add account |
| PUT | `api/accounts/<id>/` | Update account |
| DELETE | `api/accounts/<id>/delete/` | Delete account |
| GET | `api/accounts/<id>/history/` | Account balance history |
| POST | `api/accounts/sync/` | Sync API-connected accounts |
| GET | `api/net-worth/` | Net worth summary |
| GET | `api/trend/` | Historical net worth trend |

### Portfolio (`/portfolio/`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/holdings/` | Current stock holdings |
| GET | `api/account/` | Broker account summary |
| GET | `api/history/` | Portfolio value history |
| GET | `api/stock/history/` | Stock history by code |
| GET | `api/broker-values/` | Broker total values |
| GET | `api/broker-status/` | Broker connection status |

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
| `PORTFOLIO_SERVICE_URL` | — | Upstream portfolio data service URL |
| `QINIU_ACCESS_KEY` | — | Qiniu S3 access key (for database backups) |
| `QINIU_SECRET_KEY` | — | Qiniu S3 secret key |
| `QINIU_BUCKET` | — | Qiniu S3 bucket name |

## Architecture

```
numi-finance/
├── config/              # Django project settings
├── core/                # Shared: exchange rates, services, account icons
├── assets/              # Asset accounts, balance snapshots, API sync
├── expenses/            # Expenses + travel trips
├── portfolio/           # Stock portfolio (proxy to upstream data service)
├── scripts/             # Entrypoint, backup, cron setup
└── numi_app/            # Flutter app
    ├── lib/models/      # Plain Dart data classes
    ├── lib/data/        # Drift DB, repositories, remote API clients
    ├── lib/providers/   # Riverpod providers
    └── lib/ui/          # Screens and widgets
```

## CI/CD

GitHub Actions builds the Flutter APK on every push to `main` that changes `numi_app/`. macOS DMG builds can be triggered manually via `workflow_dispatch` with the `build_macos` input. Each build creates a GitHub Release tagged `vYYYYMMDD.N` (date + daily sequence) with artifacts attached. The mobile/desktop app checks for updates on launch via the GitHub Releases API. Concurrent runs on the same branch are auto-cancelled.
