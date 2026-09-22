"""Coordinates explicitly attached to a place, never a map viewport centre."""
import math
import re
from urllib.parse import parse_qs, unquote, urlsplit


def point(latitude, longitude, prefix=''):
    try:
        lat, lng = float(latitude), float(longitude)
        if not math.isfinite(lat) or not math.isfinite(lng) or not -90 <= lat <= 90 or not -180 <= lng <= 180:
            return {}
        return {prefix + 'latitude': str(lat), prefix + 'longitude': str(lng)}
    except (TypeError, ValueError):
        return {}


def google_point(url):
    from .travel_import import provider
    if provider(url) != 'Google Maps':
        return {}
    parts = urlsplit(url)
    if '/maps/dir/' in parts.path:
        return {}
    raw = unquote(parts.path + '?' + parts.query)
    # !3d/!4d identifies the selected place. @lat,lng is only camera position.
    matches = list(re.finditer(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)', raw))
    if len(matches) == 1:
        return point(*matches[0].groups())
    if len(matches) > 1:
        return {}
    params = parse_qs(parts.query)
    for key in ('query', 'q'):
        value = params.get(key, [''])[0]
        match = re.fullmatch(r'(?:loc:)?\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*', value)
        if match:
            return point(*match.groups())
    return {}
