"""Offline planner document API with optimistic concurrency and retry safety."""
import json
from datetime import date, time
from urllib.parse import urlsplit

from django.db import transaction
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_http_methods

from .models import Trip, TripPlan, TravelExpense, TRAVEL_CATEGORIES

KINDS = {'place', 'activity', 'booking', 'task', 'destination', 'person'}
FIELDS = {
    'id', 'kind', 'title', 'category', 'status', 'priority', 'date', 'endDate',
    'time', 'endTime', 'timezone', 'endTimezone', 'address', 'endAddress',
    'latitude', 'longitude', 'endLatitude', 'endLongitude', 'documentId', 'documentName',
    'links', 'notes', 'placeId', 'confirmation', 'contact',
    'cancelBy', 'assignee', 'destinationId', 'endDestinationId', 'participantIds',
}


def validate_content(content):
    if not isinstance(content, dict) or set(content) != {'items'}:
        raise ValueError('content must contain an items array')
    items = content['items']
    if not isinstance(items, list) or len(items) > 2000:
        raise ValueError('A plan supports at most 2000 items')
    ids = set()
    for item in items:
        if not isinstance(item, dict) or set(item) - FIELDS:
            raise ValueError('Invalid item fields')
        if any(not isinstance(v, str) or len(v) > 10000 for k, v in item.items() if k not in ('links', 'participantIds')):
            raise ValueError('Item values must be strings of at most 10000 characters')
        item_id = item.get('id', '')
        if not item_id or len(item_id) > 64 or item_id in ids:
            raise ValueError('Item IDs must be nonempty and unique')
        ids.add(item_id)
        if item.get('kind') not in KINDS or not (item.get('title', '').strip() or (item.get('kind') == 'activity' and item.get('placeId'))):
            raise ValueError('Each item needs a valid kind and title')
        for field in ('date', 'endDate', 'cancelBy'):
            if item.get(field):
                parsed = date.fromisoformat(item[field])
                if parsed.isoformat() != item[field]:
                    raise ValueError('Dates must use YYYY-MM-DD')
        for field in ('time', 'endTime'):
            if item.get(field):
                parsed = time.fromisoformat(item[field])
                if parsed.isoformat(timespec='minutes') != item[field] or len(item[field]) != 5:
                    raise ValueError('Times must use HH:MM')
        for lat_key, lng_key in (('latitude', 'longitude'), ('endLatitude', 'endLongitude')):
            if item.get(lat_key) or item.get(lng_key):
                from .map_locations import point
                if not point(item.get(lat_key), item.get(lng_key)):
                    raise ValueError('Map pins need valid latitude and longitude together')
        if 'status' in item:
            statuses = {'todo', 'completed'} if item['kind'] == 'task' else {'planned', 'confirmed', 'completed', 'skipped', 'cancelled'}
            if item['status'] not in statuses:
                raise ValueError('Invalid item status')
        if item['kind'] == 'booking' and item.get('category') == 'No accommodation needed' and not item.get('date'):
            raise ValueError('Bookings require a start date')
        if item['kind'] == 'destination':
            if not item.get('date') or not item.get('endDate') or item['endDate'] < item['date']:
                raise ValueError('Destinations need arrival and departure dates in order')
            if item.get('destinationId') or item.get('endDestinationId') or item.get('placeId'):
                raise ValueError('A destination cannot link to another destination or place')
        participants = item.get('participantIds', [])
        if (not isinstance(participants, list) or len(participants) > 100 or
                any(not isinstance(p, str) or not p or len(p) > 64 for p in participants) or
                len(participants) != len(set(participants))):
            raise ValueError('Invalid participants')
        if participants and item['kind'] not in ('booking', 'activity'):
            raise ValueError('Only arrangements can select participants')
        if item['kind'] == 'person' and len(item['title'].strip()) > 100:
            raise ValueError('Participant names must be at most 100 characters')
        links = item.get('links', [])
        if not isinstance(links, list) or len(links) > 50:
            raise ValueError('Links must be an array of at most 50 entries')
        for link in links:
            if not isinstance(link, dict) or set(link) != {'purpose', 'label', 'url'}:
                raise ValueError('Each link needs purpose, label and url')
            if any(not isinstance(v, str) or len(v) > 10000 for v in link.values()):
                raise ValueError('Invalid link values')
            if link['purpose'] not in ('Map', 'Website', 'Booking', 'Guide', 'Other'):
                raise ValueError('Invalid link purpose')
            url = urlsplit(link['url'])
            if url.scheme not in ('https', 'http') or not url.hostname or url.username or any(c.isspace() for c in link['url']):
                raise ValueError('Links must use http or https')
            if url.port is not None and url.port == 0:
                raise ValueError('Invalid link port')
        if item.get('category') == 'Accommodation' and item.get('kind') == 'booking':
            if not item.get('date') or not item.get('endDate') or item['endDate'] <= item['date']:
                raise ValueError('Accommodation needs checkout after check-in')
        # Transport may arrive on an earlier local calendar date across time zones.
    people = {i['id'] for i in items if i['kind'] == 'person'}
    if any(p not in people for i in items for p in i.get('participantIds', [])):
        raise ValueError('Participant no longer exists; archive people instead of deleting them')
    places = {i['id'] for i in items if i['kind'] == 'place'}
    if any(i.get('placeId') and i['placeId'] not in places for i in items):
        raise ValueError('Linked place does not exist in this trip')
    destinations = {i['id'] for i in items if i['kind'] == 'destination'}
    for item in items:
        for key in ('destinationId', 'endDestinationId'):
            if item.get(key) and item[key] not in destinations:
                raise ValueError('Linked destination does not exist in this trip')
        if item.get('endDestinationId') and (item['kind'] != 'booking' or item.get('category') not in ('Flight', 'Train', 'Bus', 'Car rental')):
            raise ValueError('Only transport bookings can link an arrival destination')
    return content


def serialize(plan):
    return {'content': plan.content, 'revision': plan.revision}


@require_http_methods(['GET', 'PUT'])
def trip_plan(request, trip_id):
    trip = Trip.objects.filter(pk=trip_id).first()
    if trip is None:
        return JsonResponse({'error': 'Trip not found'}, status=404)
    if request.method == 'GET':
        plan = TripPlan.objects.filter(trip_id=trip_id).first()
        return JsonResponse(serialize(plan) if plan else {
            'content': {'items': []}, 'revision': 0})
    try:
        if len(request.body) > 2_000_000:
            raise ValueError('Plan is too large')
        data = json.loads(request.body)
        if not isinstance(data, dict):
            raise ValueError('Expected an object')
        content = validate_content(data.get('content'))
        if any(i['kind'] == 'destination' and (i['date'] < trip.start_date.isoformat() or i['endDate'] > trip.end_date.isoformat()) for i in content['items']):
            raise ValueError('Destination dates must be within the trip dates')
        revision = data.get('revision')
        mutation = data.get('mutation_id')
        if type(revision) is not int or revision < 0:
            raise ValueError('revision must be a nonnegative integer')
        if not isinstance(mutation, str) or not 1 <= len(mutation) <= 64:
            raise ValueError('mutation_id is required (max 64 characters)')
    except (ValueError, TypeError, UnicodeDecodeError) as error:
        return JsonResponse({'error': str(error)}, status=400)
    from .collaboration import save_document, PlanConflict
    try:
        return JsonResponse(save_document(trip, content, revision, mutation, 'Owner',
                                          choice=data.get('conflict_choice'), expected_revision=data.get('expected_revision')))
    except PlanConflict as error:
        return JsonResponse({'error': str(error), 'conflicts': error.conflicts}, status=409)
    except ValueError as error:
        return JsonResponse({'error': str(error)}, status=400)


def reconcile_expense_links(trip_id, previous, content):
    """Removing arrangements only detaches links; money belongs to the ledger."""
    valid = {i['id'] for i in content['items'] if i['kind'] in ('booking', 'activity')}
    for expense in TravelExpense.objects.filter(trip_id=trip_id):
        remaining = [key for key in expense.plan_item_ids if key in valid]
        if remaining != expense.plan_item_ids:
            expense.plan_item_ids = remaining
            expense.save(update_fields=['plan_item_ids'])
    removed = {i['id'] for i in previous.get('items', []) if i['kind'] == 'destination'} - {i['id'] for i in content['items'] if i['kind'] == 'destination'}
    TravelExpense.objects.filter(trip_id=trip_id, destination_id__in=removed).update(destination_id='')


@require_http_methods(['DELETE'])
def delete_trip_by_client(request, client_id):
    # Handles a create that committed but whose response never reached the app.
    Trip.objects.filter(client_id=client_id).delete()
    return JsonResponse({'deleted': True})
