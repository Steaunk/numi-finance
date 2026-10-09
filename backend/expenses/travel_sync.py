"""Durable write receipts. The receipt and business write commit together."""
import base64
import hashlib
import json
import re
from functools import wraps
from django.db import transaction
from django.http import JsonResponse
from .models import TravelMutation


def idempotent(view):
    @wraps(view)
    def wrapped(request, *args, **kwargs):
        if request.method == 'GET':
            return view(request, *args, **kwargs)
        try:
            data = json.loads(request.body or '{}')
        except (ValueError, UnicodeDecodeError):
            return JsonResponse({'error': 'Invalid JSON'}, status=400)
        if not isinstance(data, dict):
            return JsonResponse({'error': 'Expected an object'}, status=400)
        key = request.headers.get('X-Idempotency-Key') or data.get('_mutation_id')
        if key is None:  # Backwards compatibility for released clients.
            return view(request, *args, **kwargs)
        if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_-]{16,64}', key):
            return JsonResponse({'error': 'Invalid mutation id'}, status=400)
        # Password rotation must not change a pending operation's identity.
        principal = str(request.user.pk) if request.user.is_authenticated else request.META.get('REMOTE_USER', '')
        authorization = request.headers.get('Authorization', '')
        if not principal and authorization.startswith('Basic '):
            try:
                principal = base64.b64decode(authorization[6:], validate=True).decode().split(':', 1)[0]
            except (ValueError, UnicodeDecodeError):
                pass
        scope = hashlib.sha256((request.method + request.path + '|' + principal).encode()).hexdigest()
        digest = hashlib.sha256(request.body).hexdigest()
        with transaction.atomic():
            # First SQL write serializes SQLite writers; no process-local locks.
            receipt, created = TravelMutation.objects.get_or_create(
                scope=scope, key=key, defaults={'request_hash': digest})
            if not created:
                if receipt.request_hash != digest:
                    return JsonResponse({'error': 'Mutation id already used for different data'}, status=409)
                return JsonResponse(receipt.response, status=receipt.status)
            response = view(request, *args, **kwargs)
            if 200 <= response.status_code < 300:
                receipt.response = json.loads(response.content)
                receipt.status = response.status_code
                receipt.save(update_fields=['response', 'status'])
            else:
                receipt.delete()
            return response
    return wrapped
