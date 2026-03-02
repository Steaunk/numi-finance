import json
from datetime import date

from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST, require_http_methods

from core.services import convert_amount, get_latest_rates

from .models import Expense

VALID_CURRENCIES = {'CNY', 'HKD', 'USD', 'SGD'}


@ensure_csrf_cookie
def index(request):
    return render(request, 'expenses/index.html')


@require_GET
def list_expenses(request):
    month = request.GET.get('month', date.today().strftime('%Y-%m'))
    currency = request.GET.get('currency', 'USD')
    if currency not in VALID_CURRENCIES:
        currency = 'USD'

    try:
        year, mon = month.split('-')
        year, mon = int(year), int(mon)
    except (ValueError, AttributeError):
        return JsonResponse({'error': 'Invalid month format. Use YYYY-MM'}, status=400)

    expenses = Expense.objects.filter(date__year=year, date__month=mon)

    result = []
    total = 0.0
    for exp in expenses:
        converted = convert_amount(
            exp.amount, exp.currency, currency,
            exp.rate_cny, exp.rate_hkd, exp.rate_sgd,
        )
        total += converted
        result.append({
            'id': exp.id,
            'amount': exp.amount,
            'currency': exp.currency,
            'date': exp.date.isoformat(),
            'category': exp.category,
            'name': exp.name,
            'notes': exp.notes,
            'converted_amount': converted,
            'display_currency': currency,
        })

    return JsonResponse({
        'expenses': result,
        'total_converted': round(total, 2),
        'display_currency': currency,
    })


def _validate_expense(data):
    errors = []
    amount = data.get('amount')
    if amount is None:
        errors.append('amount is required')
    else:
        try:
            amount = float(amount)
            if amount <= 0:
                errors.append('amount must be positive')
        except (TypeError, ValueError):
            errors.append('amount must be a number')

    currency = data.get('currency', '').upper()
    if currency not in VALID_CURRENCIES:
        errors.append(f'currency must be one of {", ".join(sorted(VALID_CURRENCIES))}')

    date_str = data.get('date', '')
    try:
        from datetime import datetime
        parsed_date = datetime.strptime(date_str, '%Y-%m-%d').date()
    except (ValueError, TypeError):
        errors.append('date must be in YYYY-MM-DD format')
        parsed_date = None

    category = data.get('category', '').strip()
    if not category:
        errors.append('category is required')

    name = data.get('name', '').strip()
    if not name:
        errors.append('name is required')

    notes = data.get('notes', '').strip()

    if errors:
        return None, errors

    return {
        'amount': float(amount),
        'currency': currency,
        'date': parsed_date,
        'category': category,
        'name': name,
        'notes': notes,
    }, []


@require_POST
def add_expense(request):
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    validated, errors = _validate_expense(data)
    if errors:
        return JsonResponse({'errors': errors}, status=400)

    rates = get_latest_rates()

    expense = Expense.objects.create(
        amount=validated['amount'],
        currency=validated['currency'],
        date=validated['date'],
        category=validated['category'],
        name=validated['name'],
        notes=validated['notes'],
        rate_cny=rates['cny'],
        rate_hkd=rates['hkd'],
        rate_sgd=rates['sgd'],
    )

    return JsonResponse({
        'id': expense.id,
        'amount': expense.amount,
        'currency': expense.currency,
        'date': expense.date.isoformat(),
        'category': expense.category,
        'name': expense.name,
        'notes': expense.notes,
    }, status=201)


@require_POST
def bulk_add_expenses(request):
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    if not isinstance(data, list):
        return JsonResponse({'error': 'Expected a JSON array'}, status=400)

    rates = get_latest_rates()
    created = 0
    errors = []

    for i, item in enumerate(data):
        validated, item_errors = _validate_expense(item)
        if item_errors:
            errors.append({'index': i, 'errors': item_errors})
            continue

        Expense.objects.create(
            amount=validated['amount'],
            currency=validated['currency'],
            date=validated['date'],
            category=validated['category'],
            name=validated['name'],
            notes=validated['notes'],
            rate_cny=rates['cny'],
            rate_hkd=rates['hkd'],
            rate_sgd=rates['sgd'],
        )
        created += 1

    return JsonResponse({'created': created, 'errors': errors}, status=201)


@require_http_methods(["DELETE"])
def delete_expense(request, expense_id):
    try:
        expense = Expense.objects.get(id=expense_id)
    except Expense.DoesNotExist:
        return JsonResponse({'error': 'Expense not found'}, status=404)

    expense.delete()
    return JsonResponse({'deleted': True})


@require_GET
def list_categories(request):
    categories = (
        Expense.objects.values_list('category', flat=True)
        .distinct()
        .order_by('category')
    )
    return JsonResponse({'categories': list(categories)})


@require_GET
def monthly_stats(request):
    currency = request.GET.get('currency', 'USD')
    if currency not in VALID_CURRENCIES:
        currency = 'USD'

    year = request.GET.get('year')
    if year:
        try:
            expenses = Expense.objects.filter(date__year=int(year))
        except (TypeError, ValueError):
            expenses = Expense.objects.all()
    else:
        expenses = Expense.objects.all()

    months = {}
    for exp in expenses:
        month_key = exp.date.strftime('%Y-%m')
        converted = convert_amount(
            exp.amount, exp.currency, currency,
            exp.rate_cny, exp.rate_hkd, exp.rate_sgd,
        )

        if month_key not in months:
            months[month_key] = {'total': 0.0, 'by_category': {}}

        months[month_key]['total'] += converted
        months[month_key]['total'] = round(months[month_key]['total'], 2)

        cat = exp.category
        months[month_key]['by_category'][cat] = round(
            months[month_key]['by_category'].get(cat, 0.0) + converted, 2
        )

    month_keys = sorted(months.keys())

    return JsonResponse({
        'currency': currency,
        'month_keys': month_keys,
        'months': months,
    })
