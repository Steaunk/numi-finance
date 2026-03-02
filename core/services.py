from datetime import date

import requests

from .models import ExchangeRate

RATE_API_URL = (
    "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"
)

FALLBACK_RATES = {'cny': 7.25, 'hkd': 7.82, 'sgd': 1.34, 'jpy': 150.0}


def get_latest_rates():
    """
    Return today's exchange rates as a dict: {'cny': ..., 'hkd': ..., 'sgd': ..., 'jpy': ...}.
    Fetches from API if not cached for today. Falls back to most recent cache or hardcoded.
    """
    today = date.today()

    try:
        cached = ExchangeRate.objects.get(rate_date=today)
        return {'cny': cached.cny, 'hkd': cached.hkd, 'sgd': cached.sgd, 'jpy': cached.jpy}
    except ExchangeRate.DoesNotExist:
        pass

    try:
        resp = requests.get(RATE_API_URL, timeout=10)
        resp.raise_for_status()
        data = resp.json()

        rates = {
            'cny': data['usd']['cny'],
            'hkd': data['usd']['hkd'],
            'sgd': data['usd']['sgd'],
            'jpy': data['usd']['jpy'],
        }

        ExchangeRate.objects.update_or_create(
            rate_date=today,
            defaults={
                'cny': rates['cny'],
                'hkd': rates['hkd'],
                'sgd': rates['sgd'],
                'jpy': rates['jpy'],
            },
        )

        return rates

    except Exception:
        latest = ExchangeRate.objects.order_by('-rate_date').first()
        if latest:
            return {'cny': latest.cny, 'hkd': latest.hkd, 'sgd': latest.sgd, 'jpy': latest.jpy}

        return FALLBACK_RATES.copy()


def convert_amount(amount, from_currency, to_currency, rate_cny, rate_hkd, rate_sgd, rate_jpy=150.0):
    """
    Convert amount from one currency to another using stored rate snapshot.
    All rates are: 1 USD = rate_xxx.
    """
    if from_currency == to_currency:
        return round(amount, 2)

    rates = {
        'USD': 1.0,
        'CNY': rate_cny,
        'HKD': rate_hkd,
        'SGD': rate_sgd,
        'JPY': rate_jpy,
    }

    amount_in_usd = amount / rates[from_currency]
    amount_in_target = amount_in_usd * rates[to_currency]
    return round(amount_in_target, 2)
