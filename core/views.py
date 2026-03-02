import requests as http_requests
from django.http import JsonResponse
from django.views.decorators.http import require_GET

from .services import get_latest_rates

COUNTRY_CURRENCY_MAP = {'CN': 'CNY', 'HK': 'HKD', 'SG': 'SGD', 'JP': 'JPY'}


@require_GET
def latest_rates(request):
    rates = get_latest_rates()
    return JsonResponse({
        'USD': 1.0,
        'CNY': rates['cny'],
        'HKD': rates['hkd'],
        'SGD': rates['sgd'],
        'JPY': rates['jpy'],
    })


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
