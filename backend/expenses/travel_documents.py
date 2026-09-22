"""Private ticket PDFs: preview, retain originals, and authorize every download."""
import hashlib
import io
import json
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from django.http import FileResponse, JsonResponse
from django.shortcuts import get_object_or_404
from django.views.decorators.http import require_http_methods
from .models import Trip, TravelDocument
from .collaboration import invite_for, private_response
from .travel_import import moment

MAX_BYTES = 10 * 1024 * 1024


def read_upload(request):
    upload = request.FILES.get('file')
    if not upload or not 0 < upload.size <= MAX_BYTES:
        raise ValueError('Choose one PDF up to 10 MB.')
    data = upload.read(MAX_BYTES + 1)
    if not data.startswith(b'%PDF-') or len(data) > MAX_BYTES:
        raise ValueError('Choose a valid PDF up to 10 MB.')
    name = Path(upload.name.replace('\\', '/')).name[:200]
    return data, name if name.lower().endswith('.pdf') else name + '.pdf'


def read_pdf(data, inspect_only=False):
    with tempfile.TemporaryDirectory(prefix='numi-pdf-') as directory:
        file = Path(directory) / 'ticket.pdf'
        file.write_bytes(data)
        try:
            proc = subprocess.run([sys.executable, str(Path(__file__).with_name('pdf_worker.py')), str(file),
                                   *(['--inspect'] if inspect_only else [])],
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=45 if not inspect_only else 10)
            result = json.loads(proc.stdout)
            if proc.returncode or result.get('error'):
                raise ValueError(result.get('error', 'Could not read the PDF.'))
            return result
        except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError):
            raise ValueError('PDF reading timed out or is unavailable. Try a smaller PDF.')


def ticket_moment(value):
    result = moment(value)
    if result:
        return result
    # Only unambiguous, year-bearing dates; never guess month/day order.
    value = re.sub(r'\s+', ' ', value).strip()
    for pattern in ('%d %B %Y', '%d %b %Y', '%B %d, %Y', '%Y/%m/%d', '%Y年%m月%d日'):
        for suffix in (' %H:%M', ''):
            try:
                parsed = datetime.strptime(value, pattern + suffix)
                return {'date': parsed.date().isoformat(), **({'time': parsed.strftime('%H:%M')} if suffix else {})}
            except ValueError:
                pass
    return {}


def ticket_items(text, name):
    # PDF layouts often put a value on the line after its label.
    labels = r'Flight(?: number| no\.?)?|Train(?: number| no\.?)?|Bus|Venue|Event|Hotel|From|To|Departure(?: date| time)?|Arrival(?: date| time)?|Date(?:/time| of visit)?|Time|Check.in|Check.out|Confirmation|Booking reference|航班|航班号|出发|到达|日期|时间|场地|酒店|入住|退房'
    normalized = re.sub(rf'(?im)^\s*({labels})\s*[:：]?\s*\n\s*([^\n]+)', r'\1: \2', text)
    normalized = re.sub(r'(?im)^\s*(Flight|Train)(?: number| no\.?)\s*[:：]', r'\1:', normalized)
    normalized = re.sub(r'\n[ \t]*\n+', '\n', normalized)
    blocks = re.split(r'(?=^(?:Flight|Train|Bus|Venue|Event|Hotel|航班|场地|酒店)\s*[:：])', normalized, flags=re.M | re.I)
    segments = []
    for block in blocks:
        values = {}
        for line in block.splitlines():
            match = re.match(r'^\s*([^:：]{1,30})\s*[:：]\s*(.+)$', line)
            if match:
                values[match[1].strip().lower()] = match[2].strip()
        pick = lambda *keys: next((values[k] for k in keys if k in values), '')
        flight, train, bus = pick('flight', '航班', '航班号'), pick('train'), pick('bus')
        hotel = pick('hotel', '酒店')
        venue = pick('venue', 'event', '场地')
        if not (flight or train or bus or hotel or venue):
            continue
        if flight or train or bus:
            category = 'Flight' if flight else 'Train' if train else 'Bus'
            depart = pick('departure', '出发') or ' '.join(filter(None, [pick('departure date'), pick('departure time')]))
            arrive = pick('arrival', '到达') or ' '.join(filter(None, [pick('arrival date'), pick('arrival time')]))
            item = {'kind': 'booking', 'category': category, 'title': category + ' ' + (flight or train or bus),
                    'address': pick('from', 'origin'), 'endAddress': pick('to', 'destination'), **ticket_moment(depart)}
            item.update({{'date': 'endDate', 'time': 'endTime', 'timezone': 'endTimezone'}[k]: v for k, v in ticket_moment(arrive).items()})
        elif hotel:
            arrival = ticket_moment(pick('check-in', 'check in', '入住'))
            departure = ticket_moment(pick('check-out', 'check out', '退房'))
            item = {'kind': 'booking', 'category': 'Accommodation', 'title': hotel, **arrival,
                    **{('endDate' if k == 'date' else 'endTime'): v for k, v in departure.items() if k in ('date', 'time')}}
        else:
            when = pick('date/time', 'date of visit', 'date', '日期')
            clock = pick('time', '时间')
            item = {'kind': 'activity', 'category': 'Sightseeing', 'title': venue,
                    **ticket_moment(' '.join(filter(None, [when, clock])))}
        confirmation = pick('confirmation', 'booking reference')
        if confirmation:
            item['confirmation'] = confirmation
        segments.append(item)
    if not segments:
        segments = [{'kind': 'activity', 'category': 'Other', 'title': name.removesuffix('.pdf')}]
    # Missing structured fields stay empty and require the ordinary review editor.
    for item in segments:
        item.update(source='PDF ticket', notes=text[:10000], links=[])
    return segments


def access(request, trip_id, shared, write=False):
    if shared:
        invite = invite_for(request, trip_id)
        if not invite or write and invite.role != 'editor':
            return private_response(JsonResponse({'error': 'An editor invitation is required.' if write else 'Invitation required.'}, status=403))
    return None


@require_http_methods(['POST'])
def preview(request, trip_id=None, shared=False):
    if trip_id is not None:
        denied = access(request, trip_id, shared, write=True)
        if denied is not None:
            return denied
        get_object_or_404(Trip, id=trip_id)
    try:
        data, name = read_upload(request)
        result = read_pdf(data)
        items = ticket_items(result['text'], name)
        warning = result['warning'] or 'Check extracted fields against the original ticket before saving.'
        if not result['text'].strip():
            warning = 'No readable text found. Keep the PDF and enter the ticket details manually.'
        for item in items:
            item['warning'] = warning
        return private_response(JsonResponse({'items': items, 'text': result['text'], 'name': name, 'pages': result['pages'], 'warning': warning, 'ocr': result['ocr']}))
    except ValueError as error:
        return private_response(JsonResponse({'error': str(error)}, status=400))


@require_http_methods(['POST'])
def upload(request, trip_id, shared=False):
    denied = access(request, trip_id, shared, write=True)
    if denied is not None:
        return denied
    trip = get_object_or_404(Trip, id=trip_id)
    try:
        data, name = read_upload(request)
        digest = hashlib.sha256(data).hexdigest()
        existing = TravelDocument.objects.filter(trip=trip, sha256=digest).first()
        if existing is None:
            read_pdf(data, inspect_only=True)
            existing, _ = TravelDocument.objects.get_or_create(trip=trip, sha256=digest, defaults={'name': name, 'data': data, 'size': len(data)})
        return private_response(JsonResponse({'id': str(existing.id), 'name': existing.name, 'size': existing.size}))
    except ValueError as error:
        return private_response(JsonResponse({'error': str(error)}, status=400))


@require_http_methods(['GET'])
def download(request, trip_id, document_id, shared=False):
    denied = access(request, trip_id, shared)
    if denied is not None:
        return denied
    document = get_object_or_404(TravelDocument, trip_id=trip_id, id=document_id)
    response = FileResponse(io.BytesIO(bytes(document.data)), content_type='application/pdf', as_attachment=True, filename=document.name)
    response['X-Content-Type-Options'] = 'nosniff'
    response['Content-Security-Policy'] = "sandbox; default-src 'none'"
    return private_response(response)
