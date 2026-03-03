# Numi Finance API Reference

Base URL: `https://<your-server>/`

All endpoints accept and return JSON. Authentication is handled by nginx Basic Auth (configured externally).

---

## Core

### GET `/api/rates/`

Get exchange rates (1 USD = X).

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `currencies` | string | _(all)_ | Comma-separated currency codes, e.g. `cny,hkd,thb` |
| `date` | string | `latest` | `YYYY-MM-DD` for historical rates |

**Response:**
```json
{
  "rates": {"cny": 7.25, "hkd": 7.82, "sgd": 1.34, "jpy": 150.0},
  "date": "latest"
}
```

### GET `/api/geo/currency/`

Detect default currency based on client IP geolocation (via ip-api.com).

**Response:**
```json
{"currency": "SGD"}
```

---

## Expenses

### GET `/expenses/api/expenses/`

List expenses for a given month.

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `month` | string | current month | `YYYY-MM` |
| `currency` | string | `USD` | Display currency: `CNY`, `HKD`, `USD`, `SGD` |

**Response:**
```json
{
  "expenses": [
    {
      "id": 1,
      "amount": 50.0,
      "currency": "USD",
      "date": "2026-03-01",
      "category": "Food & Drinks",
      "name": "Lunch",
      "notes": "",
      "amount_usd": 50.0,
      "amount_cny": 362.5,
      "amount_hkd": 391.0,
      "amount_sgd": 67.0,
      "converted_amount": 50.0,
      "display_currency": "USD"
    }
  ],
  "total_converted": 50.0,
  "display_currency": "USD"
}
```

### POST `/expenses/api/expenses/add/`

Create a new expense.

**Request Body:**
```json
{
  "amount": 50.0,
  "currency": "USD",
  "date": "2026-03-01",
  "category": "Food & Drinks",
  "name": "Lunch",
  "notes": ""
}
```

**Response (201):**
```json
{
  "id": 1,
  "amount": 50.0,
  "currency": "USD",
  "date": "2026-03-01",
  "category": "Food & Drinks",
  "name": "Lunch",
  "notes": "",
  "amount_usd": 50.0,
  "amount_cny": 362.5,
  "amount_hkd": 391.0,
  "amount_sgd": 67.0
}
```

### POST `/expenses/api/expenses/bulk/`

Bulk-create expenses from a JSON array.

**Request Body:**
```json
[
  {"amount": 50, "currency": "USD", "date": "2026-03-01", "category": "Food & Drinks", "name": "Lunch", "notes": ""},
  {"amount": 200, "currency": "HKD", "date": "2026-03-02", "category": "Transport", "name": "Taxi", "notes": ""}
]
```

**Response (201):**
```json
{"created": 2, "errors": []}
```

### PUT `/expenses/api/expenses/<id>/`

Update an existing expense.

**Request Body:** same as POST add.

**Response:**
```json
{"id": 1, "name": "Updated Lunch"}
```

### DELETE `/expenses/api/expenses/<id>/`

Delete an expense.

**Response:**
```json
{"deleted": true}
```

### GET `/expenses/api/categories/`

List available expense categories.

**Response:**
```json
{
  "categories": [
    "Bills, Utilities & Taxes", "Education", "Entertainment",
    "Food & Drinks", "Groceries", "Health & Fitness",
    "Housing", "Others", "Transport", "Travel"
  ]
}
```

### GET `/expenses/api/stats/monthly/`

Monthly expense statistics with category breakdown.

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `year` | string | _(all years)_ | Filter by year, e.g. `2026` |
| `currency` | string | `USD` | Display currency |

**Response:**
```json
{
  "currency": "USD",
  "month_keys": ["2026-01", "2026-02", "2026-03"],
  "months": {
    "2026-03": {
      "total": 150.0,
      "by_category": {
        "Food & Drinks": 100.0,
        "Transport": 50.0
      }
    }
  }
}
```

---

## Travel

### GET `/expenses/api/travel/trips/`

List all trips with expense summaries.

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `currency` | string | `SGD` | Display currency |

**Response:**
```json
{
  "trips": [
    {
      "id": 1,
      "destination": "Thailand",
      "start_date": "2026-03-01",
      "end_date": "2026-03-10",
      "notes": "",
      "expense_count": 5,
      "total_converted": 500.0,
      "category_totals": {"Food & Drinks": 200.0, "Transportation": 300.0}
    }
  ],
  "display_currency": "SGD"
}
```

### POST `/expenses/api/travel/trips/add/`

Create a new trip.

**Request Body:**
```json
{
  "destination": "Thailand",
  "start_date": "2026-03-01",
  "end_date": "2026-03-10",
  "notes": ""
}
```

**Response (201):**
```json
{"id": 1, "destination": "Thailand"}
```

### PUT `/expenses/api/travel/trips/<trip_id>/`

Update a trip.

**Request Body:** partial update — only include fields to change.
```json
{
  "destination": "Updated Thailand",
  "end_date": "2026-03-12",
  "notes": "Extended trip"
}
```

**Response:**
```json
{"id": 1, "destination": "Updated Thailand"}
```

### DELETE `/expenses/api/travel/trips/<trip_id>/delete/`

Delete a trip and all its expenses.

**Response:**
```json
{"deleted": true}
```

### GET `/expenses/api/travel/trips/<trip_id>/expenses/`

List expenses for a specific trip.

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `currency` | string | `SGD` | Display currency |

**Response:**
```json
{
  "trip": {
    "id": 1,
    "destination": "Thailand",
    "start_date": "2026-03-01",
    "end_date": "2026-03-10"
  },
  "expenses": [
    {
      "id": 1,
      "amount": 50.0,
      "currency": "USD",
      "date": "2026-03-02",
      "category": "Food & Drinks",
      "name": "Pad Thai",
      "notes": "",
      "amount_usd": 50.0,
      "amount_cny": 362.5,
      "amount_hkd": 391.0,
      "amount_sgd": 67.0,
      "converted_amount": 67.0
    }
  ],
  "total_converted": 67.0,
  "category_totals": {"Food & Drinks": 67.0},
  "display_currency": "SGD",
  "categories": ["Transportation", "Accommodation", "Sightseeing", "Food & Drinks", "Shopping", "Other"]
}
```

### POST `/expenses/api/travel/trips/<trip_id>/expenses/add/`

Add an expense to a trip.

**Request Body:**
```json
{
  "amount": 50.0,
  "currency": "USD",
  "date": "2026-03-02",
  "category": "Food & Drinks",
  "name": "Pad Thai",
  "notes": ""
}
```

**Response (201):**
```json
{"id": 1, "name": "Pad Thai"}
```

### PUT `/expenses/api/travel/trips/<trip_id>/expenses/<expense_id>/`

Update a trip expense.

**Request Body:** same as POST add.

**Response:**
```json
{"id": 1, "name": "Updated Pad Thai"}
```

### DELETE `/expenses/api/travel/trips/<trip_id>/expenses/<expense_id>/delete/`

Delete a trip expense.

**Response:**
```json
{"deleted": true}
```

---

## Assets

### GET `/assets/api/accounts/`

List all accounts with live-converted balances.

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `currency` | string | `SGD` | Display currency |

**Response:**
```json
{
  "accounts": [
    {
      "id": 1,
      "name": "DBS Savings",
      "currency": "SGD",
      "balance": 10000.0,
      "include_in_total": true,
      "converted_balance": 10000.0,
      "notes": ""
    }
  ],
  "display_currency": "SGD",
  "total": 10000.0
}
```

### POST `/assets/api/accounts/add/`

Create a new account. Also creates an initial balance snapshot.

**Request Body:**
```json
{
  "name": "DBS Savings",
  "currency": "SGD",
  "balance": 10000.0,
  "include_in_total": true,
  "notes": ""
}
```

Valid currencies: `CNY`, `HKD`, `USD`, `SGD`, `JPY`.

**Response (201):**
```json
{"id": 1, "name": "DBS Savings"}
```

### PUT `/assets/api/accounts/<account_id>/`

Update an account. If `balance` changes, creates a new balance snapshot.

**Request Body:** partial update — only include fields to change.
```json
{
  "name": "Updated DBS Savings",
  "balance": 12000.0,
  "include_in_total": true,
  "notes": "Updated"
}
```

**Response:**
```json
{"id": 1, "name": "Updated DBS Savings", "balance": 12000.0}
```

### DELETE `/assets/api/accounts/<account_id>/delete/`

Delete an account and all its snapshots.

**Response:**
```json
{"deleted": true}
```

### GET `/assets/api/accounts/<account_id>/history/`

Get balance history for an account (last 50 snapshots).

**Response:**
```json
{
  "account": "DBS Savings",
  "currency": "SGD",
  "history": [
    {"date": "2026-03-04", "balance": 12000.0, "change": 2000.0},
    {"date": "2026-03-01", "balance": 10000.0, "change": 10000.0}
  ]
}
```

### GET `/assets/api/net-worth/`

Get total net worth across all accounts (using live rates).

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `currency` | string | `SGD` | Display currency |

**Response:**
```json
{"currency": "SGD", "total": 22000.0}
```

### GET `/assets/api/trend/`

Get historical net worth trend (using snapshot-stored rates).

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `currency` | string | `SGD` | Display currency |

**Response:**
```json
{
  "currency": "SGD",
  "dates": ["2026-03-01", "2026-03-02", "2026-03-04"],
  "values": [20000.0, 21000.0, 22000.0]
}
```

---

## Error Responses

All endpoints return errors in a consistent format:

**Validation errors (400):**
```json
{"errors": ["amount is required", "date must be in YYYY-MM-DD format"]}
```

**Single error (400):**
```json
{"error": "Invalid JSON"}
```

**Not found (404):**
```json
{"error": "Expense not found"}
```

**Method not allowed (405):** returned automatically by Django decorators.

---

## Models

### Expense
| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Auto-increment PK |
| `amount` | float | Original amount |
| `currency` | string(3) | Original currency code |
| `date` | date | Expense date |
| `category` | string(50) | One of 10 predefined categories |
| `name` | string(100) | Expense description |
| `notes` | text | Optional notes |
| `amount_usd/cny/hkd/sgd` | float | Pre-computed converted amounts |
| `created_at` | datetime | Auto-set on creation |

### Trip
| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Auto-increment PK |
| `destination` | string(200) | Trip destination |
| `start_date` | date | Trip start |
| `end_date` | date | Trip end |
| `notes` | text | Optional notes |
| `created_at` | datetime | Auto-set on creation |

### TravelExpense
Same fields as Expense, plus `trip` (FK to Trip).

### Account
| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Auto-increment PK |
| `name` | string(100) | Account name |
| `currency` | string(3) | `CNY`/`HKD`/`USD`/`SGD`/`JPY` |
| `balance` | float | Current balance |
| `include_in_total` | bool | Include in net worth calculation |
| `notes` | text | Optional notes |
| `created_at` | datetime | Auto-set on creation |
| `updated_at` | datetime | Auto-updated on save |

### BalanceSnapshot
| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Auto-increment PK |
| `account` | FK(Account) | Parent account |
| `balance` | float | Balance at snapshot time |
| `change` | float | Delta from previous balance |
| `snapshot_date` | date | Snapshot date |
| `amount_usd/cny/hkd/sgd` | float | Pre-computed converted amounts |
| `created_at` | datetime | Auto-set on creation |

### ExchangeRate
| Field | Type | Description |
|-------|------|-------------|
| `rate_date` | date | Unique, one entry per day |
| `cny/hkd/sgd/jpy` | float | 1 USD = X rate |
| `fetched_at` | datetime | Auto-set on creation |
