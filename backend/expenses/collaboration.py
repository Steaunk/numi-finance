"""Trip-scoped sharing and revision-aware item edits. Shared responses exclude money."""
import copy
import hashlib
import json
import secrets
from datetime import timedelta

from django.db import transaction
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render
from django.utils import timezone
from django.views.decorators.csrf import ensure_csrf_cookie
from django.views.decorators.http import require_http_methods

from .models import Trip, TripPlan, TripPlanChange, TripInvite
from .planning import FIELDS, validate_content, reconcile_expense_links, serialize

PRIVATE = {'amount', 'currency', 'paymentStatus', 'paidDate', 'expenseClientId', 'expenseCategory'}
PUBLIC = FIELDS - PRIVATE
MISSING = object()


class PlanConflict(ValueError):
    def __init__(self, message='Some fields changed. Review the highlighted changes.', conflicts=None):
        super().__init__(message)
        self.conflicts = conflicts or []


def public_content(content):
    return {'items': [{k: v for k, v in i.items() if k in PUBLIC} for i in content['items']]}


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def merge_content(base, local, remote, choice=None):
    """Three-way, field-level merge. Deletes and concurrent order changes conflict."""
    b, l, r = ({i['id']: i for i in c['items']} for c in (base, local, remote))
    result = copy.deepcopy(r)
    conflicts = []
    for key in b.keys() | l.keys():
        old, new, current = b.get(key), l.get(key), r.get(key)
        if old == new or new == current:
            continue
        if old is None:
            if current is None:
                result[key] = copy.deepcopy(new)
            else:
                conflicts.append({'id': key, 'field': '*', 'local': new, 'remote': current})
        elif new is None:
            if current == old or current is None:
                result.pop(key, None)
            else:
                conflicts.append({'id': key, 'field': '*', 'local': None, 'remote': current})
        elif current is None:
            conflicts.append({'id': key, 'field': '*', 'local': new, 'remote': None})
        else:
            for field in old.keys() | new.keys():
                before, after, actual = old.get(field, MISSING), new.get(field, MISSING), current.get(field, MISSING)
                if before == after or after == actual:
                    continue
                if actual != before:
                    conflicts.append({'id': key, 'field': field,
                                      'local': None if after is MISSING else after,
                                      'remote': None if actual is MISSING else actual})
                elif after is MISSING:
                    result[key].pop(field, None)
                else:
                    result[key][field] = copy.deepcopy(after)
    common = set(b) & set(l) & set(r)
    orders = [[i['id'] for i in c['items'] if i['id'] in common] for c in (base, local, remote)]
    reordered = orders[0] != orders[1]
    if reordered and orders[2] not in (orders[0], orders[1]):
        conflicts.append({'id': '', 'field': 'order', 'local': orders[1], 'remote': orders[2]})
    if conflicts and choice not in ('local', 'server'):
        raise PlanConflict(conflicts=conflicts)
    if choice == 'local':
        for conflict in conflicts:
            key, field = conflict['id'], conflict['field']
            if field == '*':
                if key in l:
                    result[key] = copy.deepcopy(l[key])
                else:
                    result.pop(key, None)
            elif field != 'order':
                if field in l[key]:
                    result[key][field] = copy.deepcopy(l[key][field])
                else:
                    result[key].pop(field, None)
    if choice == 'server' and any(c['field'] == 'order' for c in conflicts):
        reordered = False
    order = [i['id'] for i in (local if reordered else remote)['items'] if i['id'] in result]
    order += [i['id'] for i in local['items'] if i['id'] in result and i['id'] not in order]
    order += [key for key in result if key not in order]
    return {'items': [result[key] for key in order]}


def save_document(trip, content, revision, mutation, actor, *, shared=False, operations=None, choice=None, expected_revision=None):
    if type(revision) is not int or revision < 0 or not isinstance(mutation, str) or not 1 <= len(mutation) <= 64:
        raise ValueError('A revision and mutation_id are required')
    request_hash = fingerprint({'content': content, 'operations': operations, 'revision': revision, 'shared': shared, 'actor': actor, 'choice': choice, 'expected_revision': expected_revision})
    with transaction.atomic():
        plan, _ = TripPlan.objects.get_or_create(trip=trip, defaults={'content': {'items': []}})
        previous = TripPlanChange.objects.filter(trip=trip, mutation_id=mutation).first()
        if previous:
            if previous.request_hash != request_hash:
                raise PlanConflict('Mutation ID reused with different content')
            return {'content': previous.content, 'revision': previous.revision}
        if choice is not None and (choice not in ('local', 'server') or type(expected_revision) is not int):
            raise ValueError('Conflict resolution needs a choice and expected_revision')
        if choice is not None and plan.revision != expected_revision:
            raise PlanConflict('The plan changed again. Review the latest version first.')
        # Seed existing documents so old offline edits can be compared safely.
        TripPlanChange.objects.get_or_create(trip=trip, revision=plan.revision,
                                             defaults={'content': plan.content, 'actor': 'Imported'})
        base = TripPlanChange.objects.filter(trip=trip, revision=revision).first()
        if base is None:
            raise PlanConflict('This revision is unavailable. Refresh before editing.')
        if operations is not None:
            if not isinstance(operations, list) or not 1 <= len(operations) <= 100:
                raise ValueError('Send between 1 and 100 item operations')
            content = copy.deepcopy(base.content)
            mapping = {i['id']: i for i in content['items']}
            touched = set()
            for op in operations:
                if not isinstance(op, dict) or set(op) - {'id', 'changes', 'delete', 'replace'}:
                    raise ValueError('Invalid item operation')
                key = op.get('id')
                if not isinstance(key, str) or not key or key in touched:
                    raise ValueError('Each operation needs a unique item ID')
                touched.add(key)
                if op.get('delete') is True:
                    if 'changes' in op:
                        raise ValueError('Cannot edit and delete together')
                    removed = mapping.pop(key, None)
                    if removed and removed['kind'] in ('place', 'destination'):
                        for linked in mapping.values():
                            for field in ('destinationId', 'endDestinationId'):
                                if linked.get(field) == key:
                                    linked[field] = ''
                            if linked.get('placeId') == key:
                                linked.update(placeId='', title=linked.get('title') or removed['title'],
                                              destinationId=removed.get('destinationId', ''))
                    continue
                changes = op.get('changes')
                if not isinstance(changes, dict) or set(changes) - (PUBLIC if shared else FIELDS):
                    raise ValueError('Invalid or private fields')
                if 'id' in changes and changes['id'] != key:
                    raise ValueError('Item identities cannot be changed')
                original = mapping.get(key, {})
                if op.get('replace') is True:
                    original = {k: v for k, v in original.items() if shared and k in PRIVATE}
                mapping[key] = {**original, **changes, 'id': key}
            content = {'items': list(mapping.values())}
        elif shared:
            raise ValueError('Shared editors must submit item operations')
        merged = merge_content(base.content, content, plan.content, choice=choice)
        validate_content(merged)
        from .models import TravelDocument
        import uuid
        for item in merged['items']:
            if item.get('documentId'):
                try:
                    document_id = uuid.UUID(item['documentId'])
                except ValueError:
                    raise ValueError('Invalid PDF attachment')
                if not TravelDocument.objects.filter(trip=trip, id=document_id).exists():
                    raise ValueError('PDF attachment does not belong to this trip')
        if any(i['kind'] == 'destination' and
               (i['date'] < trip.start_date.isoformat() or i['endDate'] > trip.end_date.isoformat())
               for i in merged['items']):
            raise ValueError('Destination dates must be within the trip dates')
        # Record even an unchanged mutation so a retry cannot resurrect a deletion.
        changed = TripPlan.objects.filter(pk=plan.pk, revision=plan.revision).update(
            content=merged, revision=plan.revision + 1, mutation_id=mutation, updated_at=timezone.now())
        if not changed:
            raise PlanConflict('Another edit arrived. Retry with the latest revision.')
        reconcile_expense_links(trip.id, plan.content, merged)
        TripPlanChange.objects.create(trip=trip, revision=plan.revision + 1, content=merged,
                                      actor=actor, mutation_id=mutation, request_hash=request_hash)
        plan.refresh_from_db()
        return serialize(plan)


def json_body(request):
    if len(request.body) > 2_000_000:
        raise ValueError('Request too large')
    value = json.loads(request.body)
    if not isinstance(value, dict):
        raise ValueError('Expected an object')
    return value


def invite_for(request, trip_id):
    invite_id = request.session.get('travel_grants', {}).get(str(trip_id))
    return TripInvite.objects.filter(id=invite_id, trip_id=trip_id, revoked_at__isnull=True,
                                     expires_at__gt=timezone.now()).first()


def private_response(response):
    response['Cache-Control'] = 'no-store'
    response['Referrer-Policy'] = 'no-referrer'
    response['X-Frame-Options'] = 'DENY'
    return response


@ensure_csrf_cookie
@require_http_methods(['GET'])
def workspace(request, trip_id, shared=False):
    if not shared:
        get_object_or_404(Trip, id=trip_id)
    return private_response(render(request, 'expenses/collaboration.html', {
        'boot': {'tripId': trip_id, 'shared': shared,
                 'api': f'/travel/shared/{trip_id}/' if shared else f'/expenses/api/travel/trips/{trip_id}/collaboration/'}}))


@require_http_methods(['POST', 'DELETE'])
def session(request, trip_id):
    if request.method == 'DELETE':
        grants = request.session.get('travel_grants', {})
        grants.pop(str(trip_id), None)
        request.session['travel_grants'] = grants
        return private_response(JsonResponse({'ok': True}))
    try:
        token = json_body(request).get('token', '')
        if not isinstance(token, str) or not 32 <= len(token) <= 100:
            raise ValueError('Invalid invitation')
        invite = TripInvite.objects.filter(trip_id=trip_id, token_hash=hashlib.sha256(token.encode()).hexdigest(),
                                           revoked_at__isnull=True, expires_at__gt=timezone.now()).first()
        if not invite:
            return private_response(JsonResponse({'error': 'Invitation expired or revoked.'}, status=403))
        request.session.cycle_key()
        grants = request.session.get('travel_grants', {})
        grants[str(trip_id)] = invite.id
        request.session['travel_grants'] = grants
        request.session.set_expiry(60 * 60 * 24 * 14)
        return private_response(JsonResponse({'ok': True}))
    except (ValueError, TypeError, UnicodeDecodeError) as error:
        return private_response(JsonResponse({'error': str(error)}, status=400))


@require_http_methods(['GET', 'POST'])
def data(request, trip_id, shared=False):
    invite = invite_for(request, trip_id) if shared else None
    if shared and not invite:
        return private_response(JsonResponse({'error': 'Open a valid invitation to access this trip.'}, status=403))
    trip = get_object_or_404(Trip, id=trip_id)
    try:
        if request.method == 'POST':
            if shared and invite.role != 'editor':
                return private_response(JsonResponse({'error': 'This invitation is view-only.'}, status=403))
            body = json_body(request)
            if not isinstance(body.get('operations'), list):
                raise ValueError('Item operations are required')
            result = save_document(trip, None, body.get('revision'), body.get('mutation_id'),
                                   invite.name if shared else 'Owner', shared=True, operations=body.get('operations'))
        else:
            plan = TripPlan.objects.filter(trip=trip).first()
            result = serialize(plan) if plan else {'content': {'items': []}, 'revision': 0}
        if shared:
            result = {'content': public_content(result['content']), 'revision': result['revision']}
        result.update(trip={'id': trip.id, 'destination': trip.destination,
                            'start_date': trip.start_date.isoformat(), 'end_date': trip.end_date.isoformat()},
                      role=invite.role if shared else 'owner', person_id=invite.person_id if shared else '',
                      actor=invite.name if shared else 'Owner')
        return private_response(JsonResponse(result))
    except PlanConflict as error:
        conflicts = error.conflicts
        if shared:
            conflicts = [{**c, 'local': ({k: v for k, v in c['local'].items() if k in PUBLIC} if isinstance(c.get('local'), dict) else c.get('local')),
                          'remote': ({k: v for k, v in c['remote'].items() if k in PUBLIC} if isinstance(c.get('remote'), dict) else c.get('remote'))}
                         for c in conflicts if c['field'] not in PRIVATE]
        return private_response(JsonResponse({'error': str(error), 'conflicts': conflicts}, status=409))
    except (ValueError, TypeError, UnicodeDecodeError) as error:
        return private_response(JsonResponse({'error': str(error)}, status=400))


@require_http_methods(['GET'])
def history(request, trip_id, shared=False):
    if shared and not invite_for(request, trip_id):
        return private_response(JsonResponse({'error': 'Invitation required'}, status=403))
    get_object_or_404(Trip, id=trip_id)
    changes = list(TripPlanChange.objects.filter(trip_id=trip_id)[:50])
    return private_response(JsonResponse({'changes': [
        {'revision': c.revision, 'actor': c.actor, 'created_at': c.created_at.isoformat(),
         'content': public_content(c.content)} for c in changes]}))


@require_http_methods(['GET', 'POST', 'DELETE'])
def invites(request, trip_id):
    trip = get_object_or_404(Trip, id=trip_id)
    try:
        if request.method == 'GET':
            return private_response(JsonResponse({'invites': list(trip.invites.order_by('-created_at').values(
                'id', 'name', 'role', 'person_id', 'expires_at', 'revoked_at'))}))
        body = json_body(request)
        if request.method == 'DELETE':
            trip.invites.filter(id=body.get('id'), revoked_at__isnull=True).update(revoked_at=timezone.now())
            return private_response(JsonResponse({'ok': True}))
        name, role, person = body.get('name', ''), body.get('role'), body.get('person_id', '')
        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 100 or role not in ('viewer', 'editor'):
            raise ValueError('Choose a name and viewer/editor access')
        plan = TripPlan.objects.filter(trip=trip).first()
        people = {i['id'] for i in (plan.content['items'] if plan else []) if i['kind'] == 'person'}
        if not isinstance(person, str) or (person and person not in people):
            raise ValueError('Choose a participant from this trip')
        token = secrets.token_urlsafe(32)
        invite = TripInvite.objects.create(trip=trip, token_hash=hashlib.sha256(token.encode()).hexdigest(),
                                           name=name.strip(), role=role, person_id=person,
                                           expires_at=timezone.now() + timedelta(days=30))
        url = request.build_absolute_uri(f'/travel/shared/{trip.id}/') + '#invite=' + token
        return private_response(JsonResponse({'id': invite.id, 'url': url, 'expires_at': invite.expires_at.isoformat()}, status=201))
    except (ValueError, TypeError, UnicodeDecodeError) as error:
        return private_response(JsonResponse({'error': str(error)}, status=400))


@require_http_methods(['POST'])
def map_preview(request, trip_id, shared=False):
    if shared and not invite_for(request, trip_id):
        return private_response(JsonResponse({'error': 'Invitation required'}, status=403))
    get_object_or_404(Trip, id=trip_id)
    from .travel_import import analyze, provider
    from .map_locations import google_point
    try:
        url = json_body(request).get('url', '')
        if not isinstance(url, str) or len(url) > 3000 or provider(url) != 'Google Maps':
            raise ValueError('Use a Google Maps place link.')
        result = google_point(url) or analyze('', url)
        return private_response(JsonResponse({key: result[key] for key in ('latitude', 'longitude') if key in result}))
    except (ValueError, TypeError, UnicodeDecodeError):
        return private_response(JsonResponse({'error': 'Use a Google Maps place link.'}, status=400))
