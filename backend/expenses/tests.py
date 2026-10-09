import base64
import copy
import json
from unittest.mock import patch
from django.test import TestCase
from .models import Trip, TripPlan, TravelExpense, TravelMutation


class PlannerTests(TestCase):
    def setUp(self):
        self.trip = Trip.objects.create(destination='Kyoto', start_date='2026-10-10', end_date='2026-10-14')
        self.url = f'/expenses/api/travel/trips/{self.trip.pk}/plan/'
        self.doc = {
            'places': [{'id': 'p' * 32, 'title': 'Hotel', 'lat': 0, 'lng': 0}],
            'entries': [{'id': 'e' * 32, 'title': 'Stay', 'kind': 'hotel', 'date': '2026-10-10', 'end_date': '2026-10-14', 'place_id': 'p' * 32, 'time': '15:00', 'timezone': 'Asia/Tokyo', 'status': 'confirmed'}],
            'checks': [{'id': 'c' * 32, 'title': 'Passport', 'kind': 'packing', 'done': False}],
            'day_notes': {'2026-10-10': 'Take the train'},
        }

    def put(self, doc=None, version=0, key='a' * 32):
        return self.client.put(self.url, json.dumps({'document': self.doc if doc is None else doc, 'version': version, '_mutation_id': key}), content_type='application/json')

    def test_empty_existing_trip_and_missing_trip(self):
        self.assertEqual(self.client.get(self.url).json(), {'version': 0, 'document': {}})
        self.assertEqual(self.client.get('/expenses/api/travel/trips/999/plan/').status_code, 404)

    def test_round_trip_and_zero_coordinates(self):
        self.assertEqual(self.put().status_code, 200)
        self.assertEqual(self.client.get(self.url).json(), {'version': 1, 'document': self.doc})

    def test_replay_returns_same_version_and_response(self):
        first, replay = self.put(), self.put()
        self.assertEqual(first.json(), replay.json())
        self.assertEqual(TripPlan.objects.get(trip=self.trip).version, 1)
        self.assertEqual(TravelMutation.objects.count(), 1)

    def test_stale_edit_preserves_server_and_returns_conflict(self):
        self.put()
        other = copy.deepcopy(self.doc)
        other['entries'][0]['title'] = 'Different hotel'
        response = self.put(other, key='b' * 32)
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()['document'], self.doc)
        self.assertEqual(TripPlan.objects.get(trip=self.trip).document, self.doc)
        # A new mutation based on the conflict revision can explicitly replace it.
        self.assertEqual(self.put(other, version=1, key='c' * 32).json()['version'], 2)

    def test_changed_payload_cannot_reuse_receipt(self):
        self.put()
        response = self.put({}, version=1)
        self.assertEqual(response.status_code, 409)
        self.assertEqual(TripPlan.objects.get(trip=self.trip).version, 1)

    def test_invalid_documents_do_not_write_or_leave_receipts(self):
        changes = [
            lambda d: d['entries'][0].update(place_id='missing'),
            lambda d: d['entries'][0].update(end_date='2026-10-09'),
            lambda d: d['entries'][0].update(time='25:00'),
            lambda d: d['entries'][0].update(timezone='Invalid/Zone'),
            lambda d: d['places'][0].update(lat=float('nan')),
            lambda d: d['places'][0].update(url='javascript:alert(1)'),
            lambda d: d['entries'].append(copy.deepcopy(d['entries'][0])),
            lambda d: d['checks'][0].update(done='true'),
        ]
        for change in changes:
            doc = copy.deepcopy(self.doc)
            change(doc)
            with self.subTest(doc=doc):
                self.assertEqual(self.put(doc).status_code, 400)
        self.assertFalse(TripPlan.objects.exists())
        self.assertFalse(TravelMutation.objects.exists())

    def test_malformed_payloads_return_400(self):
        for value in ['[]', 'null', '{bad', '{"version":true,"document":{}}']:
            self.assertEqual(self.client.put(self.url, value, content_type='application/json').status_code, 400)

    def test_trip_delete_cascades_plan_and_replays(self):
        self.put()
        url = f'/expenses/api/travel/trips/{self.trip.pk}/delete/'
        data = json.dumps({'_mutation_id': 'd' * 32})
        self.assertEqual(self.client.delete(url, data, content_type='application/json').status_code, 200)
        self.assertEqual(self.client.delete(url, data, content_type='application/json').status_code, 200)
        self.assertFalse(TripPlan.objects.exists())


class TravelWriteTests(TestCase):
    @patch('expenses.views.get_rates', return_value={'usd': 1, 'cny': 7, 'hkd': 8, 'sgd': 1.3})
    def test_trip_and_expense_timeout_replays_do_not_duplicate(self, _rates):
        payload = {'destination': 'Tokyo', 'start_date': '2026-10-10', 'end_date': '2026-10-12', '_mutation_id': 't' * 32}
        one = self.client.post('/expenses/api/travel/trips/add/', payload, content_type='application/json')
        two = self.client.post('/expenses/api/travel/trips/add/', payload, content_type='application/json')
        self.assertEqual(one.status_code, 201)
        self.assertEqual(one.json(), two.json())
        self.assertEqual(Trip.objects.count(), 1)
        trip_id = one.json()['id']
        url = f'/expenses/api/travel/trips/{trip_id}/expenses/add/'
        expense = {'amount': 50, 'currency': 'USD', 'date': '2026-10-10', 'category': 'Food & Drinks', 'name': 'Lunch', 'planner_entry_id': 'e' * 32, '_mutation_id': 'x' * 32}
        one = self.client.post(url, expense, content_type='application/json')
        two = self.client.post(url, expense, content_type='application/json')
        self.assertEqual(one.status_code, 201)
        self.assertEqual(one.json(), two.json())
        self.assertEqual(TravelExpense.objects.count(), 1)
        listing = self.client.get(f'/expenses/api/travel/trips/{trip_id}/expenses/').json()
        self.assertEqual(listing['expenses'][0]['planner_entry_id'], 'e' * 32)
        expense['amount'] = 60
        expense['_mutation_id'] = 'y' * 32
        url = f'/expenses/api/travel/trips/{trip_id}/expenses/{one.json()["id"]}/'
        self.assertEqual(self.client.put(url, json.dumps(expense), content_type='application/json').status_code, 200)
        self.assertEqual(self.client.put(url, json.dumps(expense), content_type='application/json').status_code, 200)
        self.assertEqual(TravelExpense.objects.get().amount, 60)

    def test_password_rotation_does_not_change_replay_identity(self):
        data = {'destination': 'Tokyo', 'start_date': '2026-10-10', 'end_date': '2026-10-12', '_mutation_id': 'r' * 32}
        for password in ('old-password', 'new-password'):
            header = 'Basic ' + base64.b64encode(f'alice:{password}'.encode()).decode()
            response = self.client.post('/expenses/api/travel/trips/add/', data, content_type='application/json', HTTP_AUTHORIZATION=header)
            self.assertEqual(response.status_code, 201)
        self.assertEqual(Trip.objects.count(), 1)

    def test_released_client_without_mutation_key_still_works(self):
        response = self.client.post('/expenses/api/travel/trips/add/', {'destination': 'Tokyo', 'start_date': '2026-10-10', 'end_date': '2026-10-12'}, content_type='application/json')
        self.assertEqual(response.status_code, 201)
