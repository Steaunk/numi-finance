import json
import math
from datetime import date

from django.db import transaction
from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_GET, require_POST, require_http_methods

from core.services import compute_snapshot_amounts, get_rates

from .models import Expense, EXPENSE_CATEGORIES, TRAVEL_CATEGORIES, Trip, TravelExpense, TripPlan

DISPLAY_CURRENCIES = {'CNY', 'HKD', 'USD', 'SGD'}


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
            'amount_usd': exp.amount_usd,
            'amount_cny': exp.amount_cny,
            'amount_hkd': exp.amount_hkd,
            'amount_sgd': exp.amount_sgd,
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
    elif category not in EXPENSE_CATEGORIES:
        errors.append('category must be one of the existing categories')

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

    rates = get_rates()
    amounts = compute_snapshot_amounts(validated['amount'], validated['currency'], rates)

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

    rates = get_rates()
    created = 0
    errors = []

    for i, item in enumerate(data):
        validated, item_errors = _validate_expense(item)
        if item_errors:
            errors.append({'index': i, 'errors': item_errors})
            continue

        amounts = compute_snapshot_amounts(validated['amount'], validated['currency'], rates)
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


@require_http_methods(["PUT", "DELETE"])
def expense_detail(request, expense_id):
    try:
        expense = Expense.objects.get(id=expense_id)
    except Expense.DoesNotExist:
        return JsonResponse({'error': 'Expense not found'}, status=404)

    if request.method == 'DELETE':
        expense.delete()
        return JsonResponse({'deleted': True})

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    validated, errors = _validate_expense(data)
    if errors:
        return JsonResponse({'errors': errors}, status=400)

    rates = get_rates()
    amounts = compute_snapshot_amounts(validated['amount'], validated['currency'], rates)

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
            'client_id': trip.client_id,
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

    client_id = data.get('client_id')
    if client_id is not None and (not isinstance(client_id, str) or not 1 <= len(client_id) <= 64):
        return JsonResponse({'errors': ['Invalid client_id']}, status=400)
    fields = dict(destination=destination, start_date=start_date, end_date=end_date,
                  notes=data.get('notes', '').strip())
    if client_id:
        trip, _ = Trip.objects.get_or_create(client_id=client_id, defaults=fields)
    else:
        trip = Trip.objects.create(**fields)
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
            return JsonResponse({'errors': ['start_date must be YYYY-MM-DD']}, status=400)
    if 'end_date' in data:
        try:
            trip.end_date = datetime.strptime(data['end_date'], '%Y-%m-%d').date()
        except (ValueError, TypeError):
            return JsonResponse({'errors': ['end_date must be YYYY-MM-DD']}, status=400)
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
            'client_id': exp.client_id,
            'plan_item_ids': exp.plan_item_ids,
            'destination_id': exp.destination_id,
            'amount': exp.amount,
            'currency': exp.currency,
            'date': exp.date.isoformat(),
            'category': exp.category,
            'name': exp.name,
            'notes': exp.notes,
            'amount_usd': exp.amount_usd,
            'amount_cny': exp.amount_cny,
            'amount_hkd': exp.amount_hkd,
            'amount_sgd': exp.amount_sgd,
            'converted_amount': converted,
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


def valid_expense_destination(trip_id, destination_id):
    if not isinstance(destination_id, str) or len(destination_id) > 64:
        return False
    if not destination_id:
        return True
    plan = TripPlan.objects.filter(trip_id=trip_id).first()
    return bool(plan and any(i.get('kind') == 'destination' and i.get('id') == destination_id
                             for i in plan.content.get('items', [])))


def valid_expense_links(trip_id, ids):
    if (not isinstance(ids, list) or len(ids) > 2000 or
            any(not isinstance(i, str) or not i or len(i) > 64 for i in ids) or
            len(ids) != len(set(ids))):
        return False
    plan = TripPlan.objects.filter(trip_id=trip_id).first()
    valid = {i['id'] for i in (plan.content.get('items', []) if plan else [])
             if i.get('kind') in ('activity', 'booking') and i.get('category') != 'No accommodation needed'}
    return set(ids) <= valid


@require_POST
@transaction.atomic
def add_trip_expense(request, trip_id):
    try:
        trip = Trip.objects.get(id=trip_id)
    except Trip.DoesNotExist:
        return JsonResponse({'error': 'Trip not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    client_id = data.get('client_id')
    if client_id is not None:
        if not isinstance(client_id, str) or not 1 <= len(client_id) <= 64:
            return JsonResponse({'error': 'Invalid expense identity'}, status=400)
        existing = TravelExpense.objects.filter(client_id=client_id).first()
        if existing:
            if existing.trip_id != trip_id:
                return JsonResponse({'error': 'Expense belongs to another trip'}, status=400)
            return JsonResponse({'id': existing.id, 'name': existing.name})
    plan_item_ids = data.get('plan_item_ids', [])
    if not valid_expense_links(trip_id, plan_item_ids):
        return JsonResponse({'error': 'Choose itinerary items in this trip'}, status=400)
    destination_id = data.get('destination_id', '')
    if not valid_expense_destination(trip_id, destination_id):
        return JsonResponse({'error': 'Choose a destination in this trip'}, status=400)
    errors = []
    amount = data.get('amount')
    try:
        amount = float(amount)
        if not math.isfinite(amount) or amount <= 0:
            errors.append('amount must be positive')
    except (TypeError, ValueError):
        errors.append('amount must be a number')

    currency = data.get('currency', '').upper()
    rates = get_rates()
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
    elif category not in TRAVEL_CATEGORIES:
        errors.append('category must be one of the existing travel categories')

    name = data.get('name', '').strip()
    if not name:
        errors.append('name is required')

    if errors:
        return JsonResponse({'errors': errors}, status=400)

    amounts = compute_snapshot_amounts(amount, currency, rates)
    values = dict(
        trip=trip,
        plan_item_ids=plan_item_ids,
        destination_id=destination_id,
        amount=amount,
        currency=currency,
        date=exp_date,
        category=category,
        name=name,
        notes=data.get('notes', '').strip(),
        **amounts,
    )
    if client_id:
        values['client_id'] = client_id
    from django.db import transaction
    with transaction.atomic():
        exp, _ = TravelExpense.objects.get_or_create(client_id=client_id, defaults=values) if client_id else (TravelExpense.objects.create(**values), True)
        if exp.trip_id != trip_id:
            return JsonResponse({'error': 'Expense belongs to another trip'}, status=400)
    return JsonResponse({'id': exp.id, 'name': exp.name}, status=201)


@require_http_methods(["PUT"])
@transaction.atomic
def update_trip_expense(request, trip_id, expense_id):
    try:
        exp = TravelExpense.objects.get(id=expense_id, trip_id=trip_id)
    except TravelExpense.DoesNotExist:
        return JsonResponse({'error': 'Expense not found'}, status=404)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)

    plan_item_ids = data.get('plan_item_ids', exp.plan_item_ids)
    if not valid_expense_links(trip_id, plan_item_ids):
        return JsonResponse({'error': 'Choose itinerary items in this trip'}, status=400)
    destination_id = data.get('destination_id', exp.destination_id)
    if not valid_expense_destination(trip_id, destination_id):
        return JsonResponse({'error': 'Choose a destination in this trip'}, status=400)
    errors = []
    amount = data.get('amount')
    try:
        amount = float(amount)
        if not math.isfinite(amount) or amount <= 0:
            errors.append('amount must be positive')
    except (TypeError, ValueError):
        errors.append('amount must be a number')

    currency = data.get('currency', '').upper()
    rates = get_rates()
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
    elif category not in TRAVEL_CATEGORIES:
        errors.append('category must be one of the existing travel categories')

    name = data.get('name', '').strip()
    if not name:
        errors.append('name is required')

    if errors:
        return JsonResponse({'errors': errors}, status=400)

    amounts = compute_snapshot_amounts(amount, currency, rates)
    exp.plan_item_ids = plan_item_ids
    exp.destination_id = destination_id
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


@require_http_methods(['PUT'])
@transaction.atomic
def update_expense_links(request, trip_id, expense_id):
    expense = TravelExpense.objects.filter(id=expense_id, trip_id=trip_id).first()
    if expense is None:
        return JsonResponse({'error': 'Expense not found'}, status=404)
    try:
        data = json.loads(request.body)
        if not isinstance(data, dict) or set(data) != {'plan_item_ids'} or not valid_expense_links(trip_id, data['plan_item_ids']):
            raise ValueError('Choose itinerary items in this trip')
    except (ValueError, TypeError):
        return JsonResponse({'error': 'Choose itinerary items in this trip'}, status=400)
    expense.plan_item_ids = data['plan_item_ids']
    expense.save(update_fields=['plan_item_ids'])
    return JsonResponse({'id': expense.id, 'plan_item_ids': expense.plan_item_ids})
