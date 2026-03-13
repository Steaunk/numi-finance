import logging
import math
import re

import requests as http_requests
from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.http import require_GET

logger = logging.getLogger(__name__)

_UPSTREAM_URL = getattr(settings, 'PORTFOLIO_SERVICE_URL', '')
_TIMEOUT = 10


def _sanitize(obj):
    """Replace NaN/Infinity with None so the result is valid JSON."""
    if isinstance(obj, float) and (math.isnan(obj) or math.isinf(obj)):
        return None
    if isinstance(obj, dict):
        return {k: _sanitize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_sanitize(v) for v in obj]
    return obj


def _proxy_get(path, query_params=None):
    """Proxy a GET request to the internal portfolio data service."""
    if not _UPSTREAM_URL:
        return JsonResponse({'error': 'Portfolio service not configured'}, status=503)
    url = f'{_UPSTREAM_URL}{path}'
    try:
        resp = http_requests.get(url, params=query_params, timeout=_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        return JsonResponse(_sanitize(data), safe=False)
    except http_requests.ConnectionError:
        logger.warning('Portfolio data service unreachable')
        return JsonResponse({'error': 'Portfolio service unavailable'}, status=503)
    except http_requests.Timeout:
        return JsonResponse({'error': 'Portfolio service timeout'}, status=504)
    except Exception as e:
        logger.error('Error proxying request: %s', e)
        return JsonResponse({'error': 'Internal service error'}, status=502)


def _validate_days(raw):
    """Validate and clamp the days query parameter."""
    try:
        return str(min(365, max(1, int(raw))))
    except (ValueError, TypeError):
        return '30'


# Only allow alphanumeric, dots, hyphens, underscores, spaces in stock names
_STOCK_NAME_RE = re.compile(r"^[\w.\- ()&',/]+$")


@require_GET
def holdings(request):
    return _proxy_get('/api/portfolio')


@require_GET
def account(request):
    return _proxy_get('/api/account')


@require_GET
def history(request):
    days = _validate_days(request.GET.get('days', '30'))
    return _proxy_get('/api/portfolio/history', {'days': days})


@require_GET
def stock_history(request, stock_name=None):
    days = _validate_days(request.GET.get('days', '30'))
    code = request.GET.get('code', '')
    if code:
        # 用 code 查（更可靠）
        return _proxy_get(f'/api/stock/_/history', {'code': code, 'days': days})
    if stock_name and _STOCK_NAME_RE.match(stock_name):
        return _proxy_get(f'/api/stock/{stock_name}/history', {'days': days})
    return JsonResponse({'error': 'Invalid stock name or missing code'}, status=400)


@require_GET
def exchange_rates(request):
    return _proxy_get('/api/exchange_rates')


@require_GET
def broker_values(request):
    return _proxy_get('/api/broker_values')


@require_GET
def broker_status(request):
    return _proxy_get('/api/broker_status')
