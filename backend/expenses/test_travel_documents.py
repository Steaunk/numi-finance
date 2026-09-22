import json
import io
import shutil
from unittest.mock import patch
from django.test import TestCase, Client
from django.core.files.uploadedfile import SimpleUploadedFile
from .models import Trip, TripPlan, TravelDocument
from .travel_documents import ticket_items, read_pdf


def sample_pdf(text='Venue: YAYOI KUSAMA MUSEUM\nDate: 10 October 2026\nTime: 11:00'):
    # Small real PDF fixture with explicit labels and selectable text.
    commands = ['BT /F1 14 Tf 50 750 Td']
    for line in text.splitlines():
        line = line.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')
        commands.append(f'({line}) Tj 0 -24 Td')
    stream = ('\n'.join(commands) + '\nET').encode()
    objects = [b'<< /Type /Catalog /Pages 2 0 R >>', b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
               b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
               b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
               b'<< /Length ' + str(len(stream)).encode() + b' >>\nstream\n' + stream + b'\nendstream']
    data = b'%PDF-1.4\n'; offsets = [0]
    for i, value in enumerate(objects, 1):
        offsets.append(len(data)); data += f'{i} 0 obj\n'.encode() + value + b'\nendobj\n'
    xref = len(data)
    data += b'xref\n0 6\n0000000000 65535 f \n' + b''.join(f'{n:010d} 00000 n \n'.encode() for n in offsets[1:])
    return data + f'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode()


class TravelDocumentTests(TestCase):
    def setUp(self):
        self.trip = Trip.objects.create(destination='Tokyo', start_date='2026-10-03', end_date='2026-10-12')
        self.base = f'/expenses/api/travel/trips/{self.trip.id}/'
        self.shared = f'/travel/shared/{self.trip.id}/'

    def file(self, data=None):
        return SimpleUploadedFile('ticket.pdf', sample_pdf() if data is None else data, content_type='application/pdf')

    def test_real_pdf_preview_no_writes_and_original_roundtrip(self):
        response = self.client.post('/expenses/api/travel/pdf-preview/', {'file': self.file()})
        self.assertEqual(response.status_code, 200, response.content)
        item = response.json()['items'][0]
        self.assertEqual((item['title'], item['date'], item['time']), ('YAYOI KUSAMA MUSEUM', '2026-10-10', '11:00'))
        self.assertFalse(TravelDocument.objects.exists())
        self.assertFalse(TripPlan.objects.exists())
        response = self.client.post(self.base+'documents/', {'file': self.file()})
        self.assertEqual(response.status_code, 200, response.content)
        doc = response.json()
        again = self.client.post(self.base+'documents/', {'file': self.file()}).json()
        self.assertEqual(again['id'], doc['id'])
        original = self.client.get(self.base+f'documents/{doc["id"]}/')
        self.assertEqual(b''.join(original.streaming_content), sample_pdf())
        self.assertIn('attachment;', original['Content-Disposition'])
        self.assertEqual(original['Cache-Control'], 'no-store')

    def test_worker_uses_python_under_embedded_uwsgi(self):
        with patch('expenses.travel_documents.sys.executable', '/usr/local/bin/uwsgi'):
            result = read_pdf(sample_pdf())
        self.assertIn('YAYOI KUSAMA MUSEUM', result['text'])

    def test_multiple_flights_separate_dates_and_reference(self):
        items = ticket_items('Flight number: SQ637\nFrom: NRT\nTo: SIN\nDeparture date: 12 October 2026\nDeparture time: 11:10\nArrival: 2026-10-12 17:20\nBooking reference: ABC123\nFlight: SQ638\nDeparture: 2026-10-15 09:00', 'trip.pdf')
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]['time'], '11:10')
        self.assertEqual(items[0]['confirmation'], 'ABC123')
        self.assertEqual(items[1]['date'], '2026-10-15')
        unknown = ticket_items('Ticket\nDate: 10/11\nPaid: 2026-09-22', 'unknown.pdf')[0]
        self.assertNotIn('date', unknown)

    def test_invalid_encrypted_oversized_and_worker_timeout(self):
        self.assertEqual(self.client.post('/expenses/api/travel/pdf-preview/', {'file': self.file(b'not pdf')}).status_code, 400)
        self.assertEqual(self.client.post('/expenses/api/travel/pdf-preview/', {'file': self.file(b'%PDF-broken')}).status_code, 400)
        self.assertEqual(self.client.post('/expenses/api/travel/pdf-preview/', {'file': self.file(b'%PDF-'+b'0'*(10*1024*1024))}).status_code, 400)
        import subprocess
        with patch('expenses.travel_documents.subprocess.run', side_effect=subprocess.TimeoutExpired('pdf', 45)):
            with self.assertRaisesRegex(ValueError, 'timed out'):
                read_pdf(sample_pdf())

    def test_scanned_pdf_ocr_when_available(self):
        if not shutil.which('tesseract'):
            self.skipTest('OCR is verified in the production Docker image')
        from PIL import Image, ImageDraw, ImageFont
        image = Image.new('RGB', (1600, 700), 'white')
        draw = ImageDraw.Draw(image)
        font = ImageFont.load_default(size=38)
        for row, line in enumerate(['Venue: YAYOI KUSAMA MUSEUM', 'Date: 10 October 2026', 'Time: 11:00']):
            draw.text((70, 70 + row * 85), line, font=font, fill='black')
        output = io.BytesIO();image.save(output, format='PDF', resolution=150)
        result = read_pdf(output.getvalue())
        self.assertTrue(result['ocr'])
        self.assertIn('2026', result['text'])
        self.assertIn('11:00', result['text'])

    def guest(self, role):
        invite = self.client.post(self.base+'collaboration/invites/', json.dumps({'name': 'Guest', 'role': role}), content_type='application/json').json()
        guest = Client()
        self.assertEqual(guest.post(self.shared+'session/', json.dumps({'token': invite['url'].split('#invite=')[1]}), content_type='application/json').status_code, 200)
        return guest, invite['id']

    def test_trip_isolation_guest_permissions_and_revocation(self):
        doc = self.client.post(self.base+'documents/', {'file': self.file()}).json()
        download = self.shared+f'documents/{doc["id"]}/'
        self.assertEqual(Client().get(download).status_code, 403)
        viewer, _ = self.guest('viewer')
        self.assertEqual(viewer.get(download).status_code, 200)
        self.assertEqual(viewer.post(self.shared+'documents/', {'file': self.file()}).status_code, 403)
        self.assertEqual(viewer.post(self.shared+'pdf-preview/', {'file': self.file()}).status_code, 403)
        editor, invite_id = self.guest('editor')
        self.assertEqual(editor.post(self.shared+'pdf-preview/', {'file': self.file()}).status_code, 200)
        self.assertEqual(editor.post(self.shared+'documents/', {'file': self.file()}).status_code, 200)
        other = Trip.objects.create(destination='Other', start_date='2026-10-03', end_date='2026-10-12')
        self.assertEqual(self.client.get(f'/expenses/api/travel/trips/{other.id}/documents/{doc["id"]}/').status_code, 404)
        response = self.client.put(f'/expenses/api/travel/trips/{other.id}/plan/', json.dumps({'revision': 0, 'mutation_id': 'test', 'content': {'items': [{'id': 'x', 'kind': 'activity', 'title': 'X', 'documentId': doc['id']}]}}), content_type='application/json')
        self.assertEqual(response.status_code, 400)
        self.client.delete(self.base+'collaboration/invites/', json.dumps({'id': invite_id}), content_type='application/json')
        self.assertEqual(editor.get(download).status_code, 403)
