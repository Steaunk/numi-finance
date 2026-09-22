"""Read public travel share metadata into a draft; never create a reservation/payment."""
import ipaddress
import json
import re
import socket
import time
from datetime import date, datetime
from html.parser import HTMLParser
from urllib.parse import parse_qs, unquote, urljoin, urlsplit

import urllib3
from django.http import JsonResponse
from django.views.decorators.http import require_POST

PROVIDERS = {
    'Airbnb': ('airbnb.com', 'airbnb.co.uk', 'airbnb.com.sg', 'airbnb.com.hk', 'airbnb.jp', 'airbnb.cn', 'abnb.me'),
    'Trip.com': ('trip.com', 'ctrip.com', 'trip.com.hk'),
    'Google Maps': ('google.com', 'google.co.jp', 'google.co.uk', 'google.com.hk', 'google.com.sg', 'maps.app.goo.gl', 'goo.gl', 'g.co'),
}
MAX_BYTES = 1024 * 1024


def provider(url):
    try:
        parts = urlsplit(url)
        if parts.scheme not in ('http', 'https') or parts.username or parts.password or parts.port not in (None, 80, 443):
            return ''
        host = (parts.hostname or '').lower()
        for name, domains in PROVIDERS.items():
            if any(host == d or host.endswith('.' + d) for d in domains):
                return name
    except ValueError:
        pass
    return ''


def public_address(host):
    addresses = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):
        raise ValueError('Non-public address')
    return addresses[0][4][0]


def fetch_page(url):
    """Pin vetted DNS addresses and revalidate redirects. Send no account credentials."""
    deadline = time.monotonic() + 10
    for _ in range(5):
        if not provider(url):
            raise ValueError('Unsupported redirect')
        parts = urlsplit(url)
        if parts.scheme != 'https' or parts.port not in (None, 443):
            raise ValueError('HTTPS required')
        host = parts.hostname
        address = public_address(host)
        pool = urllib3.HTTPSConnectionPool(address, port=443, server_hostname=host,
            assert_hostname=host, cert_reqs='CERT_REQUIRED',
            timeout=urllib3.Timeout(connect=2, read=2))
        response = None
        try:
            response = pool.urlopen('GET', (parts.path or '/') + ('?' + parts.query if parts.query else ''),
                headers={'Host': host, 'User-Agent': 'Numi/1.0 (travel link preview)',
                         'Accept': 'text/html,application/xhtml+xml', 'Accept-Encoding': 'identity'},
                redirect=False, retries=False, preload_content=False)
            if time.monotonic() > deadline:
                raise ValueError('Preview timed out')
            if response.status in (301, 302, 303, 307, 308):
                url = urljoin(url, response.headers.get('Location', ''))
                continue
            if response.status != 200 or not any(t in response.headers.get('Content-Type', '').lower() for t in ('text/html', 'application/xhtml+xml')):
                raise ValueError('Preview unavailable')
            data = bytearray()
            while True:
                chunk = response.read(16384, decode_content=False)
                if not chunk:
                    break
                data.extend(chunk)
                if len(data) > MAX_BYTES or time.monotonic() > deadline:
                    raise ValueError('Preview too large or slow')
            return url, bytes(data).decode('utf-8', errors='replace')
        finally:
            if response:
                response.close()
            pool.close()
    raise ValueError('Too many redirects')


class Metadata(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.meta = {}
        self.title = ''
        self.in_title = False
        self.in_json = False
        self.buffer = ''
        self.documents = []
        self.trip_details = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'hotelNameRow_hotelOverview_name' in attrs.get('class', ''):
            self.trip_details['title'] = clean(attrs.get('aria-label'))
        if 'hotelAddressBar_hotelOverview_addressText' in attrs.get('class', ''):
            self.trip_details['address'] = clean(attrs.get('aria-label'))
        if tag == 'meta':
            self.meta[attrs.get('property', attrs.get('name', '')).lower()] = attrs.get('content', '')
        if tag == 'title':
            self.in_title = True
        if tag == 'script' and attrs.get('type', '').lower() == 'application/ld+json':
            self.in_json = True
            self.buffer = ''

    def handle_data(self, data):
        if self.in_title:
            self.title += data
        if self.in_json:
            self.buffer += data

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
        if tag == 'script' and self.in_json:
            self.in_json = False
            try:
                self.documents.append(json.loads(self.buffer))
            except (ValueError, RecursionError):
                pass


def clean(value, limit=500):
    return re.sub(r'\s+', ' ', value).strip()[:limit] if isinstance(value, str) else ''


def nodes(value, depth=0):
    if depth > 12:
        return
    if isinstance(value, dict):
        yield value
        for key in ('@graph', 'mainEntity', 'itemListElement', 'item', 'containsPlace', 'itinerary'):
            yield from nodes(value.get(key), depth + 1)
    elif isinstance(value, list):
        for child in value[:100]:
            yield from nodes(child, depth + 1)


def structured_place(documents):
    categories = {'Hotel': 'Accommodation', 'LodgingBusiness': 'Accommodation',
        'VacationRental': 'Accommodation', 'Apartment': 'Accommodation',
        'House': 'Accommodation', 'Accommodation': 'Accommodation',
        'Restaurant': 'Restaurant', 'CafeOrCoffeeShop': 'Cafe',
        'TouristAttraction': 'Sightseeing', 'Museum': 'Sightseeing', 'Park': 'Park',
        'LocalBusiness': 'Other', 'Place': 'Other'}
    for node in nodes(documents):
        types = node.get('@type', [])
        if isinstance(types, str):
            types = [types]
        category = next((categories[t] for t in types if isinstance(t, str) and t in categories), '') if isinstance(types, list) else ''
        if not category:
            continue
        address = node.get('address', '')
        if isinstance(address, dict):
            country = address.get('addressCountry', '')
            if isinstance(country, dict):
                country = country.get('name', '')
            address = ', '.join(filter(None, [clean(address.get(k, '')) for k in ('streetAddress', 'addressLocality', 'addressRegion', 'postalCode')] + [clean(country)]))
        return {'title': clean(node.get('name')), 'address': clean(address), 'category': category}
    return {}


def url_fields(url):
    parts = urlsplit(url)
    query = {k.lower(): v[0] for k, v in parse_qs(parts.query).items() if v}
    fields = {}
    if provider(url) == 'Google Maps':
        match = re.search(r'/maps/(?:place|search)/([^/]+)', parts.path)
        title = unquote(match.group(1)).replace('+', ' ') if match else query.get('query', query.get('q', ''))
        if title and not re.fullmatch(r'[\d.,+\-\s]+', title):
            fields['title'] = clean(title)
    if provider(url) in ('Airbnb', 'Trip.com'):
        fields['category'] = 'Accommodation' if re.search(r'hotel|/rooms/', parts.path, re.I) else 'Other'
        for key, names in [('date', ('check_in', 'checkin', 'checkindate')), ('endDate', ('check_out', 'checkout', 'checkoutdate'))]:
            for name in names:
                value = query.get(name, '')
                if re.fullmatch(r'\d{8}', value):
                    value = f'{value[:4]}-{value[4:6]}-{value[6:]}'
                try:
                    parsed = date.fromisoformat(value)
                    if 1900 <= parsed.year <= 2200:
                        fields[key] = parsed.isoformat()
                        break
                except ValueError:
                    pass
    return fields


def moment(value):
    """Preserve the supplied wall clock and explicit offset; never infer a year."""
    value = clean(value)
    match = re.search(r'\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2})?)?', value)
    if match:
        raw = match.group()
        try:
            parsed = datetime.fromisoformat(raw.replace('Z', '+00:00'))
            result = {'date': parsed.date().isoformat()}
            if 'T' in raw or ' ' in raw:
                result['time'] = parsed.strftime('%H:%M')
            if parsed.utcoffset() is not None:
                result['timezone'] = 'UTC' + parsed.strftime('%z')[:3] + ':' + parsed.strftime('%z')[3:]
            return result
        except ValueError:
            return {}
    for fmt in ('%d %B %Y %H:%M', '%d %b %Y %H:%M', '%Y年%m月%d日 %H:%M'):
        try:
            parsed = datetime.strptime(value, fmt)
            return {'date': parsed.date().isoformat(), 'time': parsed.strftime('%H:%M')}
        except ValueError:
            pass
    return {}


def arrival_fields(value):
    return { {'date': 'endDate', 'time': 'endTime', 'timezone': 'endTimezone'}[k]: v for k, v in moment(value).items() }


def location_name(value):
    if isinstance(value, dict):
        return clean(value.get('name') or value.get('iataCode'))
    return clean(value)


def structured_itinerary(documents):
    result = []
    has_trip = any(n.get('@type') == 'TouristTrip' for n in nodes(documents))
    for node in nodes(documents):
        kind = node.get('@type')
        if kind == 'LodgingReservation':
            stay = node.get('reservationFor', {})
            if isinstance(stay, dict):
                details = structured_place([stay])
                result.append({**details, 'kind': 'booking', 'category': 'Accommodation',
                               **moment(node.get('checkinTime')), **arrival_fields(node.get('checkoutTime'))})
            continue
        if kind in ('FlightReservation', 'TrainReservation'):

            node = node.get('reservationFor', {})
            if not isinstance(node, dict):
                continue
            kind = node.get('@type')
        if kind in ('Flight', 'TrainTrip', 'BusTrip'):
            category = {'Flight': 'Flight', 'TrainTrip': 'Train', 'BusTrip': 'Bus'}[kind]
            number = clean(node.get('flightNumber') or node.get('trainNumber') or node.get('busNumber'))
            origin = location_name(node.get('departureAirport') or node.get('departureStation') or node.get('departureBusStop'))
            destination = location_name(node.get('arrivalAirport') or node.get('arrivalStation') or node.get('arrivalBusStop'))
            item = {'kind': 'booking', 'category': category, 'title': clean(node.get('name')) or f'{category} {number}'.strip(),
                    'address': origin, 'endAddress': destination, **moment(node.get('departureTime')), **arrival_fields(node.get('arrivalTime'))}
            result.append(item)
        elif has_trip and kind in ('Place', 'TouristAttraction', 'Museum', 'Restaurant', 'Hotel'):
            result.append({'kind': 'place', **structured_place([node])})
        elif kind == 'Event':
            result.append({'kind': 'activity', 'category': 'Sightseeing', 'title': clean(node.get('name')),
                           'address': location_name(node.get('location')), **moment(node.get('startDate')), **arrival_fields(node.get('endDate'))})
    return result[:20]


def text_itinerary(text):
    result = []
    # Typical copied itineraries label each leg. Do not infer dates from prices,
    # ticket IDs, or yearless date fragments.
    blocks = re.split(r'\n\s*\n|(?=^(?:Flight|Train|Bus|航班|火车|列车|車次)\s*[:：])', text, flags=re.M | re.I)
    for block in blocks:
        labels = {}
        for line in block.splitlines():
            match = re.match(r'^\s*([^:：]{1,30})\s*[:：]\s*(.+)$', line)
            if match:
                labels[match[1].strip().lower()] = match[2].strip()
        pick = lambda *keys: next((labels[k] for k in keys if k in labels), '')
        flight, train, bus = pick('flight', '航班'), pick('train', '火车', '列车', '車次'), pick('bus')
        if flight or train or bus:
            category = 'Flight' if flight else 'Train' if train else 'Bus'
            item = {'kind': 'booking', 'category': category, 'title': f'{category} {flight or train or bus}',
                    'address': pick('from', 'origin', '出发地', '出發地'),
                    'endAddress': pick('to', 'destination', '到达地', '到達地'),
                    **moment(pick('departure', 'departs', '出发', '出發', '出发时间', '出發時間')),
                    **arrival_fields(pick('arrival', 'arrives', '到达', '到達', '到达时间', '到達時間'))}
            result.append(item)
        elif pick('venue', '场地', '場地'):
            result.append({'kind': 'activity', 'category': 'Sightseeing', 'title': pick('venue', '场地', '場地'),
                           **moment(pick('date/time', 'date', '日期', '时间', '時間'))})
    return result[:20]


def analyze(text, url):
    source = provider(url)
    if url and not source:
        raise ValueError('Use an Airbnb, Trip.com or Google Maps link.')
    result = {'title': '', 'address': '', 'category': 'Other', 'date': '', 'endDate': '',
              'notes': text[:10000], 'source': source or 'Shared itinerary', 'warning': ''}
    segments = text_itinerary(text)
    result.update(url_fields(url))
    final_url = url
    try:
        if not url:
            raise ValueError('Text-only itinerary')
        final_url, html = fetch_page(url)
        result.update(url_fields(final_url))
        parser = Metadata()
        parser.feed(html)
        segments = structured_itinerary(parser.documents) or segments
        if provider(final_url) == 'Trip.com':
            result.update({k: v for k, v in parser.trip_details.items() if v})
        details = structured_place(parser.documents)
        result.update({k: v for k, v in details.items() if v})
        title = clean(parser.meta.get('og:title') or parser.meta.get('twitter:title') or parser.title)
        if not result['title'] and title and not re.search(r'captcha|access denied|just a moment|sign in|log in|before you continue', title, re.I) and title.lower() not in ('google maps', 'airbnb', 'trip.com'):
            result['title'] = title
    except (ValueError, OSError, urllib3.exceptions.HTTPError, RecursionError):
        result['warning'] = 'The page could not be read. Review the shared text and complete any missing details.'
    if not result['title']:
        plain = re.sub(r'https?://[^\s<>]+', '', text).strip()
        # Use a supplied share title as a suggestion, never manufacture a venue name.
        result['title'] = clean(next((line for line in plain.splitlines() if line.strip()), ''))
    if not result['title'] and not result['warning']:
        result['warning'] = 'This link did not include a place name. Add it before saving.'
    if result['date'] and result['endDate'] and result['endDate'] <= result['date']:
        result['date'] = result['endDate'] = ''
    result['links'] = [{'url': url, 'label': source, 'purpose': 'Map' if source == 'Google Maps' else 'Booking'}] if url else []
    if segments:
        result['items'] = [{**result, **segment} for segment in segments]
        if not url:
            result['warning'] = ''
            for item in result['items']:
                item['warning'] = ''
    if final_url != url and provider(final_url):
        result['resolvedUrl'] = final_url
    return result


@require_POST
def preview(request):
    try:
        body = json.loads(request.body)
        text, url = body.get('text', ''), body.get('url', '')
        if not isinstance(text, str) or not isinstance(url, str) or len(text) > 10000 or len(url) > 3000:
            raise ValueError('Share text is too long.')
        if not text.strip() and not url or any(c.isspace() or ord(c) < 32 for c in url):
            raise ValueError('Choose a valid share link.')
        response = JsonResponse(analyze(text, url))
        response['Cache-Control'] = 'no-store'
        return response
    except (ValueError, AttributeError, TypeError):
        return JsonResponse({'error': 'Use a travel share link or itinerary text (up to 10,000 characters).'}, status=400)
