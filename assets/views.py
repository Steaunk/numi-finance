import base64
import json
from datetime import date

import requests as http_requests
from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST, require_http_methods

from core.models import VALID_CURRENCIES
from core.services import FALLBACK_RATES, convert_amount, get_all_rates, get_latest_rates

from .models import Account, BalanceSnapshot


def _compute_snapshot_amounts(balance, currency, rates):
    """Compute USD/CNY/HKD/SGD equivalents for a balance."""
    if currency == 'USD':
        amount_usd = balance
    else:
        rate = rates.get(currency.lower())
        amount_usd = balance / rate if rate else 0
    return {
        'amount_usd': round(amount_usd, 2),
        'amount_cny': round(amount_usd * rates.get('cny', FALLBACK_RATES['cny']), 2),
        'amount_hkd': round(amount_usd * rates.get('hkd', FALLBACK_RATES['hkd']), 2),
        'amount_sgd': round(amount_usd * rates.get('sgd', FALLBACK_RATES['sgd']), 2),
    }


def _extract_value_by_path(data, path):
    """Extract a numeric value from nested JSON using dot-notation path.

    Supports dict keys and integer list indices.
    E.g., "data.price" -> data["data"]["price"]
    E.g., "results.0.value" -> data["results"][0]["value"]
    """
    current = data
    for key in path.split('.'):
        if isinstance(current, list):
            try:
                current = current[int(key)]
            except (ValueError, IndexError):
                raise ValueError(f'Cannot index list with "{key}"')
        elif isinstance(current, dict):
            if key not in current:
                raise ValueError(f'Key "{key}" not found in JSON')
            current = current[key]
        else:
            raise ValueError(f'Cannot navigate into {type(current).__name__}')
    try:
        return float(current)
    except (TypeError, ValueError):
        raise ValueError(f'Value at path is not numeric: {current!r}')


def _build_auth_headers(api_auth_json):
    """Parse api_auth JSON string and return HTTP headers dict."""
    if not api_auth_json:
        return {}
    try:
        auth = json.loads(api_auth_json)
    except (json.JSONDecodeError, TypeError):
        return {}
    auth_type = auth.get('type', '')
    if auth_type == 'bearer':
        token = auth.get('token', '')
        if token:
            return {'Authorization': f'Bearer {token}'}
    elif auth_type == 'header':
        name = auth.get('name', '')
        value = auth.get('value', '')
        if name:
            return {name: value}
    elif auth_type == 'basic':
        username = auth.get('username', '')
        password = auth.get('password', '')
        credentials = base64.b64encode(f'{username}:{password}'.encode()).decode()
        return {'Authorization': f'Basic {credentials}'}
    return {}


@ensure_csrf_cookie
def index(request):
    return render(request, 'assets/index.html')


@require_GET
def list_accounts(request):
    """Current balances — uses live rates."""
    currency = request.GET.get('currency', 'SGD')
    if currency not in VALID_CURRENCIES:
        currency = 'SGD'

    rates = get_latest_rates()
    accounts = Account.objects.all()

    result = []
    total = 0.0

    for acc in accounts:
        converted = convert_amount(
            acc.balance, acc.currency, currency,
            rates['cny'], rates['hkd'], rates['sgd'], rates['jpy'],
        )
        if acc.include_in_total:
            total += converted

        result.append({
            'id': acc.id,
            'name': acc.name,
            'currency': acc.currency,
            'balance': acc.balance,
            'include_in_total': acc.include_in_total,
            'converted_balance': converted,
            'notes': acc.notes,
            'api_url': acc.api_url or '',
            'api_value_path': acc.api_value_path or '',
            'api_auth': acc.api_auth or '',
        })

    return JsonResponse({
        'accounts': result,
        'display_currency': currency,
        'total': round(total, 2),
    })


@require_POST
def add_account(request):
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    errors = []
    name = data.get('name', '').strip()
    if not name:
        errors.append('name is required')

    currency = data.get('currency', '').upper()
    if currency not in VALID_CURRENCIES:
        errors.append(f'currency must be one of {", ".join(sorted(VALID_CURRENCIES))}')

    balance = data.get('balance', 0)
    try:
        balance = float(balance)
    except (TypeError, ValueError):
        errors.append('balance must be a number')

    include_in_total = data.get('include_in_total', True)
    notes = data.get('notes', '').strip()

    if errors:
        return JsonResponse({'errors': errors}, status=400)

    api_url = data.get('api_url', '').strip() or None
    api_value_path = data.get('api_value_path', '').strip() or None
    api_auth = data.get('api_auth', '').strip() or None

    rates = get_all_rates()
    account = Account.objects.create(
        name=name,
        currency=currency,
        balance=balance,
        include_in_total=bool(include_in_total),
        notes=notes,
        api_url=api_url,
        api_value_path=api_value_path,
        api_auth=api_auth,
    )

    amounts = _compute_snapshot_amounts(balance, currency, rates)
    BalanceSnapshot.objects.create(
        account=account,
        balance=balance,
        change=balance,
        snapshot_date=date.today(),
        **amounts,
    )

    return JsonResponse({'id': account.id, 'name': account.name}, status=201)


@require_http_methods(["PUT"])
def update_account(request, account_id):
    try:
        account = Account.objects.get(id=account_id)
    except Account.DoesNotExist:
        return JsonResponse({'error': 'Account not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    new_balance = data.get('balance')
    if new_balance is not None:
        try:
            new_balance = float(new_balance)
        except (TypeError, ValueError):
            return JsonResponse({'errors': ['balance must be a number']}, status=400)

        old_balance = account.balance
        change = new_balance - old_balance
        account.balance = new_balance

        rates = get_all_rates()
        amounts = _compute_snapshot_amounts(new_balance, account.currency, rates)
        BalanceSnapshot.objects.create(
            account=account,
            balance=new_balance,
            change=change,
            snapshot_date=date.today(),
            **amounts,
        )

    if 'name' in data:
        account.name = data['name'].strip()
    if 'currency' in data:
        cur = data['currency'].upper()
        if cur in VALID_CURRENCIES:
            account.currency = cur
    if 'notes' in data:
        account.notes = data['notes'].strip()
    if 'include_in_total' in data:
        account.include_in_total = bool(data['include_in_total'])
    if 'api_url' in data:
        val = data['api_url']
        account.api_url = val.strip() if val else None
    if 'api_value_path' in data:
        val = data['api_value_path']
        account.api_value_path = val.strip() if val else None
    if 'api_auth' in data:
        val = data['api_auth']
        account.api_auth = val.strip() if val else None

    account.save()

    return JsonResponse({
        'id': account.id,
        'name': account.name,
        'balance': account.balance,
        'api_url': account.api_url or '',
        'api_value_path': account.api_value_path or '',
        'api_auth': account.api_auth or '',
    })


@require_http_methods(["DELETE"])
def delete_account(request, account_id):
    try:
        account = Account.objects.get(id=account_id)
    except Account.DoesNotExist:
        return JsonResponse({'error': 'Account not found'}, status=404)

    account.delete()
    return JsonResponse({'deleted': True})


@require_GET
def net_worth(request):
    """Current net worth — uses live rates."""
    currency = request.GET.get('currency', 'SGD')
    if currency not in VALID_CURRENCIES:
        currency = 'SGD'

    rates = get_latest_rates()
    accounts = Account.objects.all()

    total = 0.0
    for acc in accounts:
        if not acc.include_in_total:
            continue
        converted = convert_amount(
            acc.balance, acc.currency, currency,
            rates['cny'], rates['hkd'], rates['sgd'], rates['jpy'],
        )
        total += converted

    return JsonResponse({
        'currency': currency,
        'total': round(total, 2),
    })


@require_GET
def trend(request):
    """Net worth trend — uses historical rates stored in snapshots."""
    currency = request.GET.get('currency', 'SGD')
    if currency not in VALID_CURRENCIES:
        currency = 'SGD'

    amount_field = f'amount_{currency.lower()}'
    included_ids = set(
        Account.objects.filter(include_in_total=True).values_list('id', flat=True)
    )
    snapshots = list(
        BalanceSnapshot.objects
        .filter(account_id__in=included_ids)
        .order_by('snapshot_date', 'created_at')
    )

    if not snapshots:
        return JsonResponse({'currency': currency, 'dates': [], 'values': []})

    # Build latest-balance-per-account at each date (2 queries total, not N*M)
    dates = sorted({s.snapshot_date for s in snapshots})
    latest_by_account = {}  # account_id -> amount in target currency
    trend_dates = []
    trend_values = []

    snap_idx = 0
    for d in dates:
        while snap_idx < len(snapshots) and snapshots[snap_idx].snapshot_date <= d:
            s = snapshots[snap_idx]
            latest_by_account[s.account_id] = getattr(s, amount_field)
            snap_idx += 1
        trend_dates.append(d.isoformat())
        trend_values.append(round(sum(latest_by_account.values()), 2))

    return JsonResponse({
        'currency': currency,
        'dates': trend_dates,
        'values': trend_values,
    })


@require_POST
def sync_api_accounts(request):
    """Sync accounts that have api_url configured.

    Optional query param ?id=123 to sync a single account.
    Without id, syncs all accounts with api_url configured.
    """
    account_id = request.GET.get('id')
    if account_id:
        try:
            accounts = [Account.objects.get(id=int(account_id))]
        except (Account.DoesNotExist, ValueError):
            return JsonResponse({'error': 'Account not found'}, status=404)
        if not accounts[0].api_url:
            return JsonResponse({'error': 'No API sync configured for this account'}, status=400)
    else:
        accounts = list(
            Account.objects.exclude(api_url__isnull=True).exclude(api_url='')
        )

    results = []
    rates = get_all_rates()

    for account in accounts:
        if not account.api_value_path:
            results.append({'id': account.id, 'name': account.name, 'error': 'No value path configured'})
            continue

        headers = _build_auth_headers(account.api_auth)
        try:
            resp = http_requests.get(account.api_url, headers=headers, timeout=15)
            resp.raise_for_status()
            data = resp.json()
            new_balance = _extract_value_by_path(data, account.api_value_path)
        except Exception as e:
            results.append({'id': account.id, 'name': account.name, 'error': str(e)})
            continue

        old_balance = account.balance
        change = new_balance - old_balance
        account.balance = new_balance
        account.save()

        amounts = _compute_snapshot_amounts(new_balance, account.currency, rates)
        BalanceSnapshot.objects.create(
            account=account,
            balance=new_balance,
            change=change,
            snapshot_date=date.today(),
            **amounts,
        )
        results.append({
            'id': account.id,
            'name': account.name,
            'balance': new_balance,
            'change': change,
        })

    return JsonResponse({'results': results})


@require_GET
def account_history(request, account_id):
    try:
        account = Account.objects.get(id=account_id)
    except Account.DoesNotExist:
        return JsonResponse({'error': 'Account not found'}, status=404)

    snapshots = account.snapshots.order_by('-snapshot_date', '-created_at')[:50]

    return JsonResponse({
        'account': account.name,
        'currency': account.currency,
        'snapshots': [
            {
                'date': s.snapshot_date.isoformat(),
                'balance': s.balance,
                'change': s.change,
            }
            for s in snapshots
        ],
    })
