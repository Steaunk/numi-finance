import json
import math
import re
from datetime import date, time
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from .models import Trip, TripPlan
from .travel_sync import idempotent

ID = re.compile(r'^[A-Za-z0-9_-]{16,64}$')


def validate_document(doc):
    if not isinstance(doc, dict) or set(doc) - {'places', 'entries', 'checks', 'day_notes'}:
        raise ValueError('Invalid plan document')
    def text(row, key, maximum=2000, required=False):
        value = row.get(key, '')
        if not isinstance(value, str) or len(value) > maximum or (required and not value.strip()):
            raise ValueError(f'Invalid {key}')
        return value
    def day(row, key):
        value = text(row, key, 10)
        if value and (not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value) or date.fromisoformat(value).isoformat() != value):
            raise ValueError(f'Invalid {key}')
        return value
    seen = set()
    for collection in ('places', 'entries', 'checks'):
        rows = doc.get(collection, [])
        if not isinstance(rows, list) or len(rows) > 1000:
            raise ValueError(f'Too many {collection}')
        for row in rows:
            if not isinstance(row, dict):
                raise ValueError('Expected an object')
            identifier = text(row, 'id', 64, True)
            if not ID.fullmatch(identifier) or identifier in seen:
                raise ValueError('Invalid or duplicate id')
            seen.add(identifier)
            text(row, 'title', 200, True)
            text(row, 'notes', 5000)
    places = {p['id'] for p in doc.get('places', [])}
    for p in doc.get('places', []):
        text(p, 'address', 500)
        for field, limit in (('lat', 90), ('lng', 180)):
            v = p.get(field)
            if v is not None and (type(v) not in (int, float) or not math.isfinite(v) or abs(v) > limit):
                raise ValueError(f'Invalid {field}')
        if (p.get('lat') is None) != (p.get('lng') is None):
            raise ValueError('Both coordinates are required')
    for row in doc.get('places', []) + doc.get('entries', []):
        url = text(row, 'url', 2000)
        if url and not re.match(r'^https?://[^\s/]+', url, re.I):
            raise ValueError('Links must use http or https')
    for e in doc.get('entries', []):
        if e.get('kind') not in ('activity', 'food', 'transport', 'note', 'hotel', 'flight', 'train', 'booking'):
            raise ValueError('Invalid activity type')
        start, end = day(e, 'date'), day(e, 'end_date')
        if end and start and (date.fromisoformat(end) - date.fromisoformat(start)).days > 366:
            raise ValueError('A booking can span at most 366 days')
        if end and (not start or end < start):
            raise ValueError('End date must follow start date')
        for key in ('time', 'end_time'):
            value = text(e, key, 5)
            if value:
                if not re.fullmatch(r'\d{2}:\d{2}', value):
                    raise ValueError('Time must be HH:mm')
                time.fromisoformat(value)
        for key in ('timezone', 'end_timezone'):
            value = text(e, key, 100)
            if value:
                try:
                    ZoneInfo(value)
                except (ZoneInfoNotFoundError, ValueError):
                    raise ValueError('Unknown timezone')
        text(e, 'confirmation', 100)
        if e.get('status', 'pending') not in ('pending', 'confirmed', 'cancelled'):
            raise ValueError('Invalid booking status')
        if e.get('place_id') and e['place_id'] not in places:
            raise ValueError('Unknown place')
    for c in doc.get('checks', []):
        if c.get('kind') not in ('packing', 'todo') or type(c.get('done', False)) is not bool:
            raise ValueError('Invalid checklist item')
        day(c, 'due')
    notes = doc.get('day_notes', {})
    if not isinstance(notes, dict) or len(notes) > 1000:
        raise ValueError('Invalid day notes')
    for key, value in notes.items():
        day({'date': key}, 'date')
        if not key or not isinstance(value, str) or len(value) > 5000:
            raise ValueError('Invalid day note')
    return doc


@require_http_methods(['GET', 'PUT'])
@idempotent
def trip_plan(request, trip_id):
    if not Trip.objects.filter(pk=trip_id).exists():
        return JsonResponse({'error': 'Trip not found'}, status=404)
    if request.method == 'GET':
        plan = TripPlan.objects.filter(trip_id=trip_id).first()
        return JsonResponse({'version': plan.version if plan else 0, 'document': plan.document if plan else {}})
    if len(request.body) > 2_000_000:
        return JsonResponse({'error': 'Plan is too large'}, status=400)
    try:
        body = json.loads(request.body)
        if not isinstance(body, dict) or type(body.get('version')) is not int or body['version'] < 0:
            raise ValueError('A non-negative version is required')
        doc = validate_document(body.get('document'))
    except (ValueError, TypeError, UnicodeDecodeError) as exc:
        return JsonResponse({'error': str(exc)}, status=400)
    plan, _ = TripPlan.objects.get_or_create(trip_id=trip_id)
    # Compare-and-swap makes stale writes visible rather than overwriting edits.
    updated = TripPlan.objects.filter(pk=plan.pk, version=body['version']).update(
        document=doc, version=body['version'] + 1)
    if not updated:
        plan.refresh_from_db()
        return JsonResponse({'error': 'Plan changed on another device', 'version': plan.version, 'document': plan.document}, status=409)
    return JsonResponse({'version': body['version'] + 1, 'document': doc})
