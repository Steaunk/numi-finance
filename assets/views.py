import json
from datetime import date

from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST, require_http_methods

from core.models import VALID_CURRENCIES
from core.services import convert_amount, get_latest_rates

from .models import Account, BalanceSnapshot


@ensure_csrf_cookie
def index(request):
    return render(request, 'assets/index.html')


@require_GET
def list_accounts(request):
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

    rates = get_latest_rates()
    account = Account.objects.create(
        name=name,
        currency=currency,
        balance=balance,
        include_in_total=bool(include_in_total),
        notes=notes,
    )

    BalanceSnapshot.objects.create(
        account=account,
        balance=balance,
        change=balance,
        snapshot_date=date.today(),
        rate_cny=rates['cny'],
        rate_hkd=rates['hkd'],
        rate_sgd=rates['sgd'],
        rate_jpy=rates['jpy'],
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
            return JsonResponse({'error': 'balance must be a number'}, status=400)

        old_balance = account.balance
        change = new_balance - old_balance
        account.balance = new_balance

        rates = get_latest_rates()
        BalanceSnapshot.objects.create(
            account=account,
            balance=new_balance,
            change=change,
            snapshot_date=date.today(),
            rate_cny=rates['cny'],
            rate_hkd=rates['hkd'],
            rate_sgd=rates['sgd'],
            rate_jpy=rates['jpy'],
        )

    if 'name' in data:
        account.name = data['name'].strip()
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
    """Net worth trend over time based on snapshots."""
    currency = request.GET.get('currency', 'SGD')
    if currency not in VALID_CURRENCIES:
        currency = 'SGD'

    snapshots = BalanceSnapshot.objects.select_related('account').order_by('snapshot_date')
    accounts = Account.objects.all()

    date_set = set()
    for s in snapshots:
        date_set.add(s.snapshot_date)
    dates = sorted(date_set)

    if not dates:
        return JsonResponse({'currency': currency, 'dates': [], 'values': []})

    trend_data = []
    for d in dates:
        total = 0.0
        for acc in accounts:
            if not acc.include_in_total:
                continue
            snap = (
                BalanceSnapshot.objects
                .filter(account=acc, snapshot_date__lte=d)
                .order_by('-snapshot_date', '-created_at')
                .first()
            )
            if snap:
                converted = convert_amount(
                    snap.balance, acc.currency, currency,
                    snap.rate_cny, snap.rate_hkd, snap.rate_sgd, snap.rate_jpy,
                )
                total += converted

        trend_data.append({
            'date': d.isoformat(),
            'total': round(total, 2),
        })

    return JsonResponse({
        'currency': currency,
        'dates': [t['date'] for t in trend_data],
        'values': [t['total'] for t in trend_data],
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
        'history': [
            {
                'date': s.snapshot_date.isoformat(),
                'balance': s.balance,
                'change': s.change,
            }
            for s in snapshots
        ],
    })
