import logging
from datetime import date

import requests

from .models import ExchangeRate

logger = logging.getLogger(__name__)

API_URL_TEMPLATE = (
    "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{date}/v1/currencies/usd.json"
)
FALLBACK_URL_TEMPLATE = (
    "https://{date}.currency-api.pages.dev/v1/currencies/usd.json"
)

FALLBACK_RATES = {'cny': 7.25, 'hkd': 7.82, 'sgd': 1.34, 'jpy': 150.0}


def _fetch_rates_from_api(rate_date=None):
    """Fetch all USD-based rates from the fawazahmed0 API for a given date.

    Args:
        rate_date: A date string 'YYYY-MM-DD' or None for latest.

    Returns:
        dict of {currency_code: rate} (lowercase keys, 1 USD = X), or None on failure.
    """
    date_param = rate_date or 'latest'
    url = API_URL_TEMPLATE.format(date=date_param)
    fallback_url = FALLBACK_URL_TEMPLATE.format(date=date_param)

    for u in (url, fallback_url):
        try:
            resp = requests.get(u, timeout=10)
            resp.raise_for_status()
            data = resp.json()
            return data.get('usd', {})
        except Exception:
            logger.debug("Rate fetch from %s failed", u, exc_info=True)
            continue
    logger.warning("All rate API endpoints failed, will use fallback")
    return None


def get_rates(rate_date=None, currencies=None):
    """Unified rate function. Returns dict of {currency: rate} (1 USD = X).

    Args:
        rate_date: 'YYYY-MM-DD' string or None for latest.
        currencies: list of currency codes to filter, or None for all.

    Returns:
        dict like {'cny': 7.25, 'hkd': 7.82, ...}
    """
    rates = _fetch_rates_from_api(rate_date)

    if rates is None:
        # Fallback: try ExchangeRate cache, then hardcoded
        latest = ExchangeRate.objects.order_by('-rate_date').first()
        if latest:
            rates = {'cny': latest.cny, 'hkd': latest.hkd, 'sgd': latest.sgd, 'jpy': latest.jpy, 'usd': 1.0}
        else:
            rates = {**FALLBACK_RATES, 'usd': 1.0}

    # Cache today's core rates in ExchangeRate for legacy callers
    if rate_date is None and rates:
        today = date.today()
        if not ExchangeRate.objects.filter(rate_date=today).exists():
            try:
                ExchangeRate.objects.update_or_create(
                    rate_date=today,
                    defaults={
                        'cny': rates.get('cny', 7.25),
                        'hkd': rates.get('hkd', 7.82),
                        'sgd': rates.get('sgd', 1.34),
                        'jpy': rates.get('jpy', 150.0),
                    },
                )
            except Exception:
                logger.warning("Failed to cache exchange rates", exc_info=True)

    if currencies:
        keys = {c.lower() for c in currencies}
        rates = {k: v for k, v in rates.items() if k in keys}

    return rates


def get_latest_rates():
    """Legacy helper: return today's rates for the 4 core currencies."""
    rates = get_rates()
    return {k: rates.get(k, v) for k, v in FALLBACK_RATES.items()}


def get_all_rates():
    """Legacy helper: return all rates (latest)."""
    return get_rates()


def compute_snapshot_amounts(amount, currency, rates):
    """Compute USD/CNY/HKD/SGD equivalents for a balance or expense amount."""
    if currency == 'USD':
        amount_usd = amount
    else:
        rate = rates.get(currency.lower())
        amount_usd = amount / rate if rate else 0
    return {
        'amount_usd': round(amount_usd, 2),
        'amount_cny': round(amount_usd * rates.get('cny', FALLBACK_RATES['cny']), 2),
        'amount_hkd': round(amount_usd * rates.get('hkd', FALLBACK_RATES['hkd']), 2),
        'amount_sgd': round(amount_usd * rates.get('sgd', FALLBACK_RATES['sgd']), 2),
    }


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
