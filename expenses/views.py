import json
from datetime import date

from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST, require_http_methods

from core.services import get_all_rates

from .models import Expense, EXPENSE_CATEGORIES, TRAVEL_CATEGORIES, Trip, TravelExpense

DISPLAY_CURRENCIES = {'CNY', 'HKD', 'USD', 'SGD'}


def _compute_amounts(amount, currency, rates):
    """Compute USD/CNY/HKD/SGD equivalents at the given rates."""
    if currency == 'USD':
        amount_usd = amount
    else:
        rate = rates.get(currency.lower())
        amount_usd = amount / rate if rate else 0
    return {
        'amount_usd': round(amount_usd, 2),
        'amount_cny': round(amount_usd * rates.get('cny', 7.25), 2),
        'amount_hkd': round(amount_usd * rates.get('hkd', 7.82), 2),
        'amount_sgd': round(amount_usd * rates.get('sgd', 1.34), 2),
    }


@ensure_csrf_cookie
def index(request):
    return render(request, 'expenses/index.html')


@require_GET
def list_expenses(request):
    month = request.GET.get('month', date.today().strftime('%Y-%m'))
    currency = request.GET.get('currency', 'USD')
    if currency not in DISPLAY_CURRENCIES:
        currency = 'USD'

    try:
        year, mon = month.split('-')
        year, mon = int(year), int(mon)
    except (ValueError, AttributeError):
        return JsonResponse({'error': 'Invalid month format. Use YYYY-MM'}, status=400)

    amount_field = f'amount_{currency.lower()}'
    expenses = Expense.objects.filter(date__year=year, date__month=mon)

    result = []
    total = 0.0
    for exp in expenses:
        converted = getattr(exp, amount_field)
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
            'amount_usd': exp.amount_usd,
            'amount_cny': exp.amount_cny,
            'amount_hkd': exp.amount_hkd,
            'amount_sgd': exp.amount_sgd,
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
    if not currency:
        errors.append('currency is required')

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

    rates = get_all_rates()
    amounts = _compute_amounts(validated['amount'], validated['currency'], rates)

    expense = Expense.objects.create(
        amount=validated['amount'],
        currency=validated['currency'],
        date=validated['date'],
        category=validated['category'],
        name=validated['name'],
        notes=validated['notes'],
        **amounts,
    )

    return JsonResponse({
        'id': expense.id,
        'amount': expense.amount,
        'currency': expense.currency,
        'date': expense.date.isoformat(),
        'category': expense.category,
        'name': expense.name,
        'notes': expense.notes,
        'amount_usd': expense.amount_usd,
        'amount_cny': expense.amount_cny,
        'amount_hkd': expense.amount_hkd,
        'amount_sgd': expense.amount_sgd,
    }, status=201)


@require_POST
def bulk_add_expenses(request):
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    if not isinstance(data, list):
        return JsonResponse({'error': 'Expected a JSON array'}, status=400)

    rates = get_all_rates()
    created = 0
    errors = []

    for i, item in enumerate(data):
        validated, item_errors = _validate_expense(item)
        if item_errors:
            errors.append({'index': i, 'errors': item_errors})
            continue

        amounts = _compute_amounts(validated['amount'], validated['currency'], rates)
        Expense.objects.create(
            amount=validated['amount'],
            currency=validated['currency'],
            date=validated['date'],
            category=validated['category'],
            name=validated['name'],
            notes=validated['notes'],
            **amounts,
        )
        created += 1

    return JsonResponse({'created': created, 'errors': errors}, status=201)


@require_http_methods(["PUT"])
def update_expense(request, expense_id):
    try:
        expense = Expense.objects.get(id=expense_id)
    except Expense.DoesNotExist:
        return JsonResponse({'error': 'Expense not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    validated, errors = _validate_expense(data)
    if errors:
        return JsonResponse({'errors': errors}, status=400)

    rates = get_all_rates()
    amounts = _compute_amounts(validated['amount'], validated['currency'], rates)

    expense.amount = validated['amount']
    expense.currency = validated['currency']
    expense.date = validated['date']
    expense.category = validated['category']
    expense.name = validated['name']
    expense.notes = validated['notes']
    for k, v in amounts.items():
        setattr(expense, k, v)
    expense.save()

    return JsonResponse({'id': expense.id, 'name': expense.name})


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
    return JsonResponse({'categories': EXPENSE_CATEGORIES})


@require_GET
def monthly_stats(request):
    currency = request.GET.get('currency', 'USD')
    if currency not in DISPLAY_CURRENCIES:
        currency = 'USD'

    amount_field = f'amount_{currency.lower()}'

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
        converted = getattr(exp, amount_field)

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


# --- Travel Expenses ---

@ensure_csrf_cookie
def travel_index(request):
    return render(request, 'expenses/travel.html')


@require_GET
def list_trips(request):
    display = request.GET.get('currency', 'SGD').upper()
    if display not in DISPLAY_CURRENCIES:
        display = 'SGD'
    amount_field = f'amount_{display.lower()}'

    trips = Trip.objects.prefetch_related('expenses').all()
    result = []
    for trip in trips:
        total = 0.0
        category_totals = {}
        for exp in trip.expenses.all():
            converted = getattr(exp, amount_field)
            total += converted
            category_totals[exp.category] = round(
                category_totals.get(exp.category, 0.0) + converted, 2
            )

        result.append({
            'id': trip.id,
            'destination': trip.destination,
            'start_date': trip.start_date.isoformat(),
            'end_date': trip.end_date.isoformat(),
            'notes': trip.notes,
            'expense_count': trip.expenses.count(),
            'total_converted': round(total, 2),
            'category_totals': category_totals,
        })

    return JsonResponse({
        'trips': result,
        'display_currency': display,
    })


@require_POST
def add_trip(request):
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    errors = []
    destination = data.get('destination', '').strip()
    if not destination:
        errors.append('destination is required')

    from datetime import datetime
    start_date = end_date = None
    try:
        start_date = datetime.strptime(data.get('start_date', ''), '%Y-%m-%d').date()
    except (ValueError, TypeError):
        errors.append('start_date must be YYYY-MM-DD')
    try:
        end_date = datetime.strptime(data.get('end_date', ''), '%Y-%m-%d').date()
    except (ValueError, TypeError):
        errors.append('end_date must be YYYY-MM-DD')

    if start_date and end_date and end_date < start_date:
        errors.append('end_date must be >= start_date')

    if errors:
        return JsonResponse({'errors': errors}, status=400)

    trip = Trip.objects.create(
        destination=destination,
        start_date=start_date,
        end_date=end_date,
        notes=data.get('notes', '').strip(),
    )
    return JsonResponse({'id': trip.id, 'destination': trip.destination}, status=201)


@require_http_methods(["PUT"])
def update_trip(request, trip_id):
    try:
        trip = Trip.objects.get(id=trip_id)
    except Trip.DoesNotExist:
        return JsonResponse({'error': 'Trip not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    from datetime import datetime
    if 'destination' in data:
        trip.destination = data['destination'].strip()
    if 'start_date' in data:
        try:
            trip.start_date = datetime.strptime(data['start_date'], '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return JsonResponse({'error': 'Invalid start_date'}, status=400)
    if 'end_date' in data:
        try:
            trip.end_date = datetime.strptime(data['end_date'], '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return JsonResponse({'error': 'Invalid end_date'}, status=400)
    if 'notes' in data:
        trip.notes = data['notes'].strip()

    trip.save()
    return JsonResponse({'id': trip.id, 'destination': trip.destination})


@require_http_methods(["DELETE"])
def delete_trip(request, trip_id):
    try:
        trip = Trip.objects.get(id=trip_id)
    except Trip.DoesNotExist:
        return JsonResponse({'error': 'Trip not found'}, status=404)
    trip.delete()
    return JsonResponse({'deleted': True})


@require_GET
def list_trip_expenses(request, trip_id):
    try:
        trip = Trip.objects.get(id=trip_id)
    except Trip.DoesNotExist:
        return JsonResponse({'error': 'Trip not found'}, status=404)

    display = request.GET.get('currency', 'SGD').upper()
    if display not in DISPLAY_CURRENCIES:
        display = 'SGD'
    amount_field = f'amount_{display.lower()}'

    expenses = trip.expenses.all()
    result = []
    total = 0.0
    category_totals = {}
    for exp in expenses:
        converted = round(getattr(exp, amount_field), 2)
        total += converted
        category_totals[exp.category] = round(
            category_totals.get(exp.category, 0.0) + converted, 2
        )
        result.append({
            'id': exp.id,
            'amount': exp.amount,
            'currency': exp.currency,
            'date': exp.date.isoformat(),
            'category': exp.category,
            'name': exp.name,
            'notes': exp.notes,
            'converted_amount': converted,
            'amount_usd': exp.amount_usd,
            'amount_cny': exp.amount_cny,
            'amount_hkd': exp.amount_hkd,
            'amount_sgd': exp.amount_sgd,
        })

    return JsonResponse({
        'trip': {
            'id': trip.id,
            'destination': trip.destination,
            'start_date': trip.start_date.isoformat(),
            'end_date': trip.end_date.isoformat(),
        },
        'expenses': result,
        'total_converted': round(total, 2),
        'category_totals': category_totals,
        'display_currency': display,
        'categories': TRAVEL_CATEGORIES,
    })


@require_POST
def add_trip_expense(request, trip_id):
    try:
        trip = Trip.objects.get(id=trip_id)
    except Trip.DoesNotExist:
        return JsonResponse({'error': 'Trip not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    errors = []
    amount = data.get('amount')
    try:
        amount = float(amount)
        if amount <= 0:
            errors.append('amount must be positive')
    except (TypeError, ValueError):
        errors.append('amount must be a number')

    currency = data.get('currency', '').upper()
    rates = get_all_rates()
    rate = rates.get(currency.lower())
    if currency == 'USD':
        rate = 1.0
    if rate is None:
        errors.append(f'Unknown currency: {currency}')

    from datetime import datetime
    exp_date = None
    try:
        exp_date = datetime.strptime(data.get('date', ''), '%Y-%m-%d').date()
    except (ValueError, TypeError):
        errors.append('date must be YYYY-MM-DD')

    category = data.get('category', '').strip()
    if not category:
        errors.append('category is required')

    name = data.get('name', '').strip()
    if not name:
        errors.append('name is required')

    if errors:
        return JsonResponse({'errors': errors}, status=400)

    amounts = _compute_amounts(amount, currency, rates)
    exp = TravelExpense.objects.create(
        trip=trip,
        amount=amount,
        currency=currency,
        date=exp_date,
        category=category,
        name=name,
        notes=data.get('notes', '').strip(),
        **amounts,
    )
    return JsonResponse({'id': exp.id, 'name': exp.name}, status=201)


@require_http_methods(["PUT"])
def update_trip_expense(request, trip_id, expense_id):
    try:
        exp = TravelExpense.objects.get(id=expense_id, trip_id=trip_id)
    except TravelExpense.DoesNotExist:
        return JsonResponse({'error': 'Expense not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    errors = []
    amount = data.get('amount')
    try:
        amount = float(amount)
        if amount <= 0:
            errors.append('amount must be positive')
    except (TypeError, ValueError):
        errors.append('amount must be a number')

    currency = data.get('currency', '').upper()
    rates = get_all_rates()
    rate = rates.get(currency.lower())
    if currency == 'USD':
        rate = 1.0
    if rate is None:
        errors.append(f'Unknown currency: {currency}')

    from datetime import datetime
    exp_date = None
    try:
        exp_date = datetime.strptime(data.get('date', ''), '%Y-%m-%d').date()
    except (ValueError, TypeError):
        errors.append('date must be YYYY-MM-DD')

    category = data.get('category', '').strip()
    if not category:
        errors.append('category is required')

    name = data.get('name', '').strip()
    if not name:
        errors.append('name is required')

    if errors:
        return JsonResponse({'errors': errors}, status=400)

    amounts = _compute_amounts(amount, currency, rates)
    exp.amount = amount
    exp.currency = currency
    exp.date = exp_date
    exp.category = category
    exp.name = name
    exp.notes = data.get('notes', '').strip()
    for k, v in amounts.items():
        setattr(exp, k, v)
    exp.save()

    return JsonResponse({'id': exp.id, 'name': exp.name})


@require_http_methods(["DELETE"])
def delete_trip_expense(request, trip_id, expense_id):
    try:
        exp = TravelExpense.objects.get(id=expense_id, trip_id=trip_id)
    except TravelExpense.DoesNotExist:
        return JsonResponse({'error': 'Expense not found'}, status=404)
    exp.delete()
    return JsonResponse({'deleted': True})
