# Numi Finance

A multi-currency personal finance app: **Django** backend + **Flutter** (Android / macOS) client.

Tracks expenses, travel trips, asset accounts, and investment portfolios across **CNY, HKD, USD, SGD, JPY** with daily exchange rates from [fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api).

---

## Features

### Expenses
- 10 categories, monthly totals and category breakdown charts
- Bulk JSON import with per-item error reporting
- Multi-currency amounts pre-computed at write time (USD / CNY / HKD / SGD) for fast aggregation

### Travel
- Trips with destination, dates, notes
- Per-trip expenses in 6 categories (Transportation, Accommodation, Sightseeing, Food & Drinks, Shopping, Other)

### Assets
- Accounts in any supported currency with per-account "include in total" toggle
- Transfer between accounts with automatic currency conversion
- Net worth and historical trend chart across all accounts
- **API-synced accounts** — backend fetches balances from arbitrary external JSON endpoints via configurable URL + JSONPath + auth (Bearer / Basic / custom header)
- Daily cron snapshot at 01:00 UTC; app-triggered sync also snapshots if the last snapshot is >12h old (stale-while-revalidate)
- **FIRE tracker** — configurable withdrawal rate, runway estimate from 12-month trailing spend
- 17 auto-matched account icons served from the backend, MD5-versioned (banks, brokers, wallets, crypto, etc.)

### Portfolio
- Stock holdings, portfolio value history, per-stock history charts
- Fund, bond, and cash positions aggregated from broker accounts
- **ETF look-through** — pass-through to underlying constituents
- Backend is a thin proxy over a configurable upstream data service (`PORTFOLIO_SERVICE_URL`); responses are NaN/Infinity-sanitized for valid JSON

### Mobile & Desktop App
- Android APK and macOS DMG builds
- **Offline-first**: all writes hit local SQLite (Drift) first, replayed from a sync queue when online (max 5 retries)
- Connectivity listener auto-syncs on offline→online transitions
- Amounts displayable in any supported currency (selected in settings)
- **Biometric lock** with 1-minute background grace period
- In-app auto-update via GitHub Releases API

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Django 6.0.2, SQLite3, uWSGI, WhiteNoise |
| Backend infra | Docker, cron, rclone → Qiniu S3 backups |
| Frontend | Flutter, Riverpod 2, GoRouter, Drift, Dio, fl_chart |
| Frontend storage | SQLite (Drift) + SharedPreferences + FlutterSecureStorage |
| Auth | HTTP Basic (nginx) + optional biometric (`local_auth`) |
| CI | GitHub Actions (APK on every push; DMG via `workflow_dispatch`) |

---

## Architecture

```
numi-finance/
├── docker-compose.yml           Production (uwsgi + cron, builds ./backend)
├── docker-compose.dev.yml       Development (runserver + hot reload)
├── backend/                     Django project
│   ├── manage.py · requirements.txt · Dockerfile
│   ├── config/                  Settings, URLs, CSRF-exempt /api middleware
│   ├── core/                    Shared services
│   │   ├── services.py          Exchange rate fetcher (multi-source fallback + DB cache)
│   │   ├── account_icons.py     17 SVG icon mappings, MD5-versioned
│   │   └── views.py             /api/rates/, /api/geo/currency/, /api/account-icons/
│   ├── accounts/                Asset accounts (Django label still 'assets' for DB compat)
│   │   ├── models.py            Account, BalanceSnapshot (with amount_usd/cny/hkd/sgd)
│   │   ├── views.py             CRUD, net worth, trend, API-sync with JSONPath extraction
│   │   └── management/commands/sync_api_accounts.py   Daily cron job
│   ├── expenses/                Expenses + travel trips
│   │   ├── models.py            Expense, Trip, TravelExpense (pre-computed 4-currency amounts)
│   │   └── views.py             CRUD, bulk import, monthly stats
│   ├── portfolio/               Thin proxy to upstream data service
│   │   └── views.py             Proxy + NaN/Infinity sanitization + input validation
│   └── scripts/
│       ├── entrypoint.sh        Writes crontab (01:00 sync, 02:00 backup), runs migrate + uwsgi
│       └── backup.sh            rclone → Qiniu S3
└── numi_app/                    Flutter app
    └── lib/
        ├── config/              router.dart (GoRouter + ShellRoute), theme, constants
        ├── models/              Plain Dart data classes (expense, trip, account, snapshot, portfolio…)
        ├── data/
        │   ├── local/           Drift database + sync_queue table
        │   ├── remote/          Dio client + 6 endpoint modules
        │   ├── repositories/    expense / travel / asset / rate / portfolio
        │   └── sync/            sync_service.dart — full-sync orchestration
        ├── providers/           Riverpod providers split by domain
        │   ├── core.dart        Foundation: db, prefs, api clients, repos, biometric
        │   ├── sync.dart        SyncService + SyncStateNotifier + connectivity
        │   ├── expenses.dart · travel.dart · assets.dart · portfolio.dart
        │   └── providers.dart   Barrel re-export (keeps existing imports working)
        ├── ui/                  Screens + widgets, grouped by feature domain
        │   ├── expenses/ travel/ assets/ portfolio/ charts/ settings/
        │   └── common/widgets/  LockScreen, SyncStatusIndicator, AmountDisplay, …
        └── utils/               Account icons, categories, currency, dates, logger
```

> **Note on the `accounts` app**: the module folder is `backend/accounts/` but the internal Django `app_label` is kept as `'assets'` (see [apps.py](backend/accounts/apps.py)) so existing DB tables (`assets_account`, `assets_balancesnapshot`), migrations, and the `/assets/` URL prefix continue to work without a data migration.

### App navigation (5-tab bottom nav)

| Tab | Route | Screens |
|---|---|---|
| Expenses | `/expenses` | ExpenseList, AddExpense (modal) |
| Travel | `/travel` | TripList → TripDetail → AddTravelExpense |
| Assets | `/assets` | AssetOverview → AccountHistory, AddAccount / Update / Transfer |
| Stocks | `/portfolio` | PortfolioOverview → StockDetail / LookThrough |
| Charts | `/charts` | StatsScreen |

Settings is a root-level modal at `/settings`.

### Key design patterns

- **Offline-first sync queue** — local writes enqueue a `SyncOperation` (JSON payload); `SyncService.fullSync()` replays them on next connection, up to 5 retries per op.
- **Pre-computed multi-currency amounts** — every expense / snapshot stores USD / CNY / HKD / SGD at insert time; aggregation queries never hit the rate converter.
- **Stale-while-revalidate snapshots** — `PUT /accounts/<id>/` only writes a new `BalanceSnapshot` if the previous one is >12h old; daily cron guarantees at least one snapshot per account per day.
- **JSONPath account sync** — external broker / bank balances are pulled via `api_url` + `api_value_path` (e.g. `data.results.0.balance`) + optional `api_auth`.
- **Portfolio proxy** — the backend owns no portfolio data; it forwards requests to `PORTFOLIO_SERVICE_URL` and sanitizes NaN/Infinity from the upstream JSON.
- **Versioned account icons** — MD5 hash across all SVGs lets the client skip download when unchanged.
- **Biometric lock with grace period** — app lifecycle observer re-locks only after >1 min in background.

---

## Quick Start

### Docker

```bash
# Production (uwsgi + cron + backup)
docker compose up --build

# Development (runserver + hot reload)
docker compose -f docker-compose.dev.yml up --build
```

### Local

```bash
cd backend
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

---

## API Endpoints

### Core
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/rates/` | Current or historical exchange rates (`?date=YYYY-MM-DD&currencies=USD,CNY`) |
| GET | `/api/geo/currency/` | Detect default currency by client IP |
| GET | `/api/account-icons/` | Account icon mappings + inline SVG (MD5-versioned) |

### Expenses (`/expenses/`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/expenses/?month=YYYY-MM` | Monthly expenses |
| POST | `api/expenses/add/` | Add expense |
| POST | `api/expenses/bulk/` | Bulk JSON import (partial-failure tolerant) |
| PUT/DELETE | `api/expenses/<id>/` | Update / delete |
| GET | `api/categories/` | Categories list |
| GET | `api/stats/monthly/?year=YYYY` | Monthly totals + by-category |

### Travel (`/expenses/`)
| Method | Path | Description |
|--------|------|-------------|
| GET/POST | `api/travel/trips/` · `trips/add/` | List / create |
| PUT/DELETE | `api/travel/trips/<id>/` | Update / delete |
| GET/POST | `api/travel/trips/<id>/expenses/` · `.../add/` | Trip expenses |
| PUT/DELETE | `api/travel/trips/<id>/expenses/<eid>/` | Update / delete trip expense |

### Assets (`/assets/`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/accounts/` | List with live-converted balances |
| POST | `api/accounts/add/` | Add account (+ initial snapshot) |
| PUT/DELETE | `api/accounts/<id>/` | Update / delete |
| GET | `api/accounts/<id>/history/` | Last 50 balance snapshots |
| POST | `api/accounts/sync/` | Sync API-connected accounts (`?id=X&snapshot=true`) |
| GET | `api/net-worth/` | Net worth summary |
| GET | `api/trend/` | Historical net worth trend |

### Portfolio (`/portfolio/`) — proxied from `PORTFOLIO_SERVICE_URL`
| Method | Path | Description |
|--------|------|-------------|
| GET | `api/holdings/` | Current stock holdings |
| GET | `api/account/` | Broker account summary |
| GET | `api/history/?days=30` | Portfolio value history (1–365 days) |
| GET | `api/stock/history/?code=<ticker>&days=30` | Stock history by code |
| GET | `api/stock/<name>/history/?days=30` | Stock history by name |
| GET | `api/exchange-rates/` | Upstream exchange rates |
| GET | `api/broker-values/` | Broker total values |
| GET | `api/broker-status/` | Broker connection status |
| GET | `api/look-through/?limit=50` | ETF pass-through to constituents (1–200) |

---

## Bulk Import Format

```json
[
  {"amount": 50,  "currency": "USD", "date": "2026-03-01", "category": "Food & Drinks", "name": "Lunch", "notes": ""},
  {"amount": 200, "currency": "HKD", "date": "2026-03-02", "category": "Transport",     "name": "Taxi",  "notes": ""}
]
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DJANGO_SECRET_KEY` | dev placeholder | Django secret key (required in production) |
| `DEBUG` | `true` | Django debug mode |
| `DATABASE_PATH` | `db.sqlite3` | SQLite file path |
| `ALLOWED_HOSTS` | `*` | Comma-separated allowed hosts |
| `PORTFOLIO_SERVICE_URL` | — | Upstream portfolio data service URL |
| `QINIU_ACCESS_KEY` | — | Qiniu S3 access key (enables daily DB backup) |
| `QINIU_SECRET_KEY` | — | Qiniu S3 secret key |
| `QINIU_BUCKET` | — | Qiniu S3 bucket name |

---

## Scheduled Jobs

Configured in [backend/scripts/entrypoint.sh](backend/scripts/entrypoint.sh):

| Time (UTC) | Job | Purpose |
|---|---|---|
| 01:00 | `python manage.py sync_api_accounts` | Fetch balances from API-connected accounts and write daily snapshots |
| 02:00 | `backend/scripts/backup.sh` | rclone → Qiniu S3 (only if Qiniu creds provided) |

---

## CI/CD

See [.github/workflows/build-apk.yml](.github/workflows/build-apk.yml):

- **APK** built on every push to `main` that changes `numi_app/`
- **macOS DMG** triggered manually via `workflow_dispatch` with `build_macos: true`
- Each build creates a GitHub Release tagged `vYYYYMMDD.N` (date + daily sequence) with artifacts attached
- The Flutter app checks for updates on launch via the GitHub Releases API
- Concurrent runs on the same branch are auto-cancelled; `pub` packages and `.dart_tool` are cached for faster builds
