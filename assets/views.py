import json
from datetime import date

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

    rates = get_all_rates()
    account = Account.objects.create(
        name=name,
        currency=currency,
        balance=balance,
        include_in_total=bool(include_in_total),
        notes=notes,
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

    account.save()

    return JsonResponse({
        'id': account.id,
        'name': account.name,
        'balance': account.balance,
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
