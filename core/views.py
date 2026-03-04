import requests as http_requests
from django.http import JsonResponse
from django.views.decorators.http import require_GET

from .services import get_rates
from . import account_icons

COUNTRY_CURRENCY_MAP = {'CN': 'CNY', 'HK': 'HKD', 'SG': 'SGD', 'JP': 'JPY'}


@require_GET
def rates(request):
    """Unified rates endpoint.

    Query params:
        currencies - comma-separated list (e.g. ?currencies=cny,thb,eur)
        date       - YYYY-MM-DD for historical rates (omit for latest)

    Returns: {"rates": {"cny": 7.25, ...}, "date": "latest"}
    """
    currencies_param = request.GET.get('currencies', '').strip()
    date_param = request.GET.get('date', '').strip() or None

    currencies = None
    if currencies_param:
        currencies = [c.strip() for c in currencies_param.split(',') if c.strip()]

    result = get_rates(rate_date=date_param, currencies=currencies)
    return JsonResponse({'rates': result, 'date': date_param or 'latest'})


@require_GET
def detect_currency(request):
    """Detect default currency based on client IP geolocation."""
    ip = request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip()
    if not ip:
        ip = request.META.get('REMOTE_ADDR', '')

    if ip in ('127.0.0.1', '::1', ''):
        return JsonResponse({'currency': 'SGD'})

    try:
        resp = http_requests.get(f'http://ip-api.com/json/{ip}?fields=countryCode', timeout=3)
        data = resp.json()
        country = data.get('countryCode', '')
        currency = COUNTRY_CURRENCY_MAP.get(country, 'SGD')
    except Exception:
        currency = 'SGD'

    return JsonResponse({'currency': currency})


@require_GET
def account_icon_list(request):
    """Return account icon mappings + inline SVGs.

    Pass ?v=<cached_version> to skip transfer when nothing changed.
    """
    client_version = request.GET.get('v', '')
    current_version = account_icons.get_version()
    if client_version == current_version:
        return JsonResponse({'changed': False})
    return JsonResponse({
        'version': current_version,
        'icons': account_icons.get_icons(),
    })
