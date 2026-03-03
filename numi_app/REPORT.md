# Numi App — Implementation Report

> Generated 2026-03-03

## Overview

Numi is a personal finance tracker Flutter app (Android) that syncs with a self-hosted Django backend at `exp.steaunk.icu`. It supports expense tracking, travel expense management, asset (account) management, and visual charts.

---

## Architecture

### Tech Stack
| Layer | Technology |
|---|---|
| Framework | Flutter 3.29.1 |
| State management | Riverpod 2.6 (StateNotifier + FutureProvider + StreamProvider) |
| Navigation | go_router 14.8 |
| Local database | Drift 2.22 (SQLite ORM) |
| Code generation | Freezed + json_serializable + riverpod_generator |
| HTTP client | Dio 5.7 + CookieManager |
| Charts | fl_chart 0.70 |
| Connectivity | connectivity_plus |

### Directory Structure
```
lib/
├── config/
│   ├── constants.dart       # currencies, fallback rates, travel categories
│   ├── router.dart          # go_router setup with bottom nav shell
│   └── theme.dart           # Material 3 light/dark themes
├── data/
│   ├── local/
│   │   └── database.dart    # Drift tables, DAOs, AppDatabase
│   ├── remote/
│   │   ├── api_client.dart  # Dio with Basic Auth + CSRF interceptor
│   │   └── endpoints/       # ExpenseApi, TravelApi, AssetApi, RateApi, VersionApi
│   ├── repositories/        # ExpenseRepository, TravelRepository, AssetRepository, RateRepository
│   └── sync/
│       └── sync_service.dart  # Full sync orchestration + sync queue processing
├── models/                  # Dart model classes (Account, Expense, Trip, etc.)
├── providers/
│   └── providers.dart       # All Riverpod providers
├── ui/
│   ├── assets/              # AssetOverviewScreen, AddAccountScreen, UpdateAccountScreen, AccountHistoryScreen
│   ├── charts/              # StatsScreen (monthly bar chart + year trend)
│   ├── common/widgets/      # Shared UI components
│   ├── expenses/            # ExpenseListScreen, AddExpenseScreen
│   ├── settings/            # SettingsScreen
│   └── travel/              # TripListScreen, TripDetailScreen, AddTripScreen, AddTravelExpenseScreen
└── utils/                   # CurrencyUtils, CategoryUtils, AppDateUtils
```

---

## Features

### 1. Expense Tracking (`/expenses`)
- List expenses by month with left/right navigation
- Monthly total in selected display currency
- Swipe-left to delete
- Add expense: amount, currency, date, category, name, notes
- Inline edit (long-press on expense row — via commit 48ea3ea)

### 2. Travel Expenses (`/travel`)
- Trip management (destination, start/end dates)
- Per-trip expense list with per-trip total
- Expense categories: Transportation, Accommodation, Sightseeing, Food & Drinks, Shopping, Other
- Swipe-left to delete individual travel expenses

### 3. Assets (`/assets`)
- Account list with real balance + converted balance in display currency
- Net worth card (sum of `include_in_total` accounts)
- Long-press to edit account (name, balance, currency, include-in-total, notes)
- Tap to view balance history chart for an account
- Balance snapshots recorded automatically on balance change

### 4. Charts (`/charts`)
- Monthly spending bar chart (current year)
- Category breakdown per month
- Net worth trend line chart (fetched from server API or computed from local snapshots)

### 5. Settings
- **Server Connection**: URL, nginx Basic Auth username/password, Test Connection button
- **Display Currency**: USD / CNY / HKD / SGD segmented selector
- **Sync**: online/offline indicator, pending operations count, manual Sync Now button
- **App Updates**: manual Check for Updates button → shows "Up to date" or Download & Install button

---

## Data Layer

### Local Database (SQLite via Drift)

| Table | Key Fields |
|---|---|
| `expenses` | remoteId, amount, currency, date, category, name, amountUsd/Cny/Hkd/Sgd, synced |
| `trips` | remoteId, destination, startDate, endDate, synced |
| `travel_expenses` | remoteId, tripId, amount, currency, amountUsd/Cny/Hkd/Sgd, synced |
| `accounts` | remoteId, name, currency, balance, includeInTotal, synced |
| `balance_snapshots` | accountId, balance, change, snapshotDate, amountUsd/Cny/Hkd/Sgd |
| `exchange_rates` | rateDate, cny, hkd, sgd, jpy (1 row kept) |
| `sync_queue` | entityType, operation, localId, payload, retryCount |

### Sync Strategy
1. **Optimistic local write**: All creates/updates/deletes are applied locally first
2. **Immediate push**: The app tries to push to server immediately after local write
3. **Sync queue fallback**: If push fails, the operation is queued for later retry
4. **Full sync** (on startup + manual + reconnect):
   - Fetch latest exchange rates
   - For each domain: push local unsynced → pull from server (skip rows with pending local changes)
   - Process sync queue

### API Endpoints (Django backend)
```
GET    /api/rates/                          # Exchange rates
GET    /expenses/api/expenses/              # Expense list
POST   /expenses/api/expenses/add/          # Add expense
DELETE /expenses/api/expenses/{id}/delete/  # Delete expense
GET    /travel/api/trips/                   # Trip list
POST   /travel/api/trips/add/              # Add trip
DELETE /travel/api/trips/{id}/delete/
GET    /travel/api/trips/{id}/expenses/
POST   /travel/api/trips/{id}/expenses/add/
DELETE /travel/api/trips/{id}/expenses/{id}/delete/
GET    /assets/api/accounts/               # Account list + converted balance
POST   /assets/api/accounts/add/
PUT    /assets/api/accounts/{id}/          # Update account
DELETE /assets/api/accounts/{id}/delete/
GET    /assets/api/net-worth/              # Net worth total
GET    /assets/api/trend/                  # Net worth trend history
GET    /assets/api/accounts/{id}/history/ # Balance snapshots
```

---

## CI/CD Pipeline

**File**: `.github/workflows/build-apk.yml`

- Triggered on push to `main` branch when `numi_app/**` files change
- Computes a date-based version tag: `v20260303.N` (N = sequence number for the day)
- Build number = `YYYYMMDD * 100 + N` (monotonically increasing integer)
- Generates the `android/` platform directory at CI time via `flutter create --platforms android`
- Restores committed templates: `pubspec.yaml`, `test/widget_test.dart`, `AndroidManifest.xml`, `strings.xml`, `open_filex_provider_paths.xml`
- Builds release APK: `flutter build apk --release --build-number=<build_num>`
- Publishes GitHub Release with the APK attached
- Gradle dependencies cached by `pubspec.yaml` hash (restores in ~30s)

---

## Auto-Update

- **VersionApi** queries `GET https://api.github.com/repos/Steaunk/numi-finance/releases/latest` (public repo, no auth)
- Parses tag `v20260303.N` → build number `YYYYMMDD * 100 + N`
- Compares against `package_info_plus` build number
- In Settings: "Check for Updates" button triggers manual check
- If update available: "Download & Install" button → two-step download:
  1. `GET <assetApiUrl>` with `Accept: application/octet-stream` → GitHub 302 redirect to CDN URL
  2. Download from CDN → save to temp dir → open APK installer via `open_filex`

---

## Known Issues & Limitations

| # | Issue | Status |
|---|---|---|
| 1 | Expense edit not available — only delete (swipe) | Not implemented |
| 2 | `SyncQueue.retryCount` field exists but never incremented; stuck items accumulate indefinitely | Not implemented |
| 3 | Local database file still named `expense_tracker.db` | Cosmetic (changing would require migration) |
| 4 | `ExchangeRates` table has a `jpy` column but JPY was removed from display currencies | Cosmetic |

---

## Security Notes

- Nginx Basic Auth credentials stored in `SharedPreferences` (plain text on device)
- CSRF tokens from Django are automatically forwarded via the `X-CSRFToken` header on all write requests (interceptor in `ApiClient`)
- No GitHub PAT required — the release repository is public

---

## Dependencies Summary

```yaml
flutter_riverpod: ^2.6.1     # State management
go_router: ^14.8.1           # Navigation
drift: ^2.22.1               # SQLite ORM
sqlite3_flutter_libs: ^0.5.28
path_provider: ^2.1.5
path: ^1.9.1
dio: ^5.7.0                  # HTTP client
dio_cookie_manager: ^3.1.2
cookie_jar: ^4.0.8
freezed_annotation: ^2.4.4
json_annotation: ^4.9.0
fl_chart: ^0.70.2            # Charts
connectivity_plus: ^6.1.1
shared_preferences: ^2.3.4
intl: ^0.19.0
flutter_slidable: ^3.1.1
package_info_plus: ^8.1.0    # Build number for update check
open_filex: ^4.7.0           # Launch APK installer
```
