import json
from django.test import TestCase
from .models import Trip, TripPlan, TravelExpense
from unittest.mock import patch


class TripPlanTests(TestCase):
    def setUp(self):
        self.trip = Trip.objects.create(destination='Tokyo', start_date='2026-10-01', end_date='2026-10-03')
        self.url = f'/expenses/api/travel/trips/{self.trip.id}/plan/'
        self.content = {'items': [{'id': 'place1', 'kind': 'place', 'title': 'Coffee', 'links': [
            {'purpose': 'Map', 'label': 'Find it', 'url': 'https://maps.app.goo.gl/example'}]}]}

    def put(self, content=None, revision=0, mutation='first', url=None):
        return self.client.put(url or self.url, data=json.dumps({'content': self.content if content is None else content,
            'revision': revision, 'mutation_id': mutation}), content_type='application/json')

    @patch('expenses.views.get_rates', return_value={'sgd': 1.3, 'cny': 7, 'hkd': 7.8})
    def test_paid_transport_can_be_unscheduled_without_changing_payment(self, _rates):
        flight = {'id': 'flight', 'kind': 'booking', 'title': 'Connection', 'category': 'Flight',
                  'date': '2026-10-01', 'time': '05:15', 'endDate': '2026-10-01', 'endTime': '09:25',
                  'status': 'confirmed'}
        self.assertEqual(self.put({'items': [flight]}).status_code, 200)
        payment = list(TravelExpense.objects.values())
        flight.update(date='', time='', endDate='', endTime='')
        response = self.put({'items': [flight]}, revision=1, mutation='unschedule')
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(self.client.get(self.url).json()['content']['items'][0]['date'], '')
        self.assertEqual(list(TravelExpense.objects.values()), payment)
        for category in ('Accommodation', 'No accommodation needed'):
            self.assertEqual(self.put({'items': [{**flight, 'category': category}]},
                                     revision=2, mutation=category).status_code, 400)

    @patch('expenses.views.get_rates', return_value={'sgd': 1.3, 'cny': 7, 'hkd': 7.8})
    def test_standalone_expense_city_roundtrip_and_destination_removal(self, _rates):
        city = {'id': 'kyoto', 'kind': 'destination', 'title': 'Kyoto',
                'date': '2026-10-01', 'endDate': '2026-10-03'}
        self.assertEqual(self.put({'items': [city]}).status_code, 200)
        body = {'client_id': 'water', 'amount': 5, 'currency': 'SGD', 'date': '2026-09-21',
                'category': 'Other', 'name': 'Water', 'destination_id': 'kyoto'}
        base = f'/expenses/api/travel/trips/{self.trip.id}/expenses/'
        response = self.client.post(base + 'add/', data=json.dumps(body), content_type='application/json')
        self.assertEqual(response.status_code, 201, response.content)
        expense = TravelExpense.objects.get(pk=response.json()['id'])
        self.assertIsNone(expense.plan_item_id)
        self.assertEqual(self.client.get(base).json()['expenses'][0]['destination_id'], 'kyoto')
        # Older clients omit the field: ordinary edits must preserve it.
        update = {k: v for k, v in body.items() if k != 'destination_id'}
        update['amount'] = 7
        self.assertEqual(self.client.put(base + f'{expense.id}/', data=json.dumps(update), content_type='application/json').status_code, 200)
        expense.refresh_from_db()
        self.assertEqual(expense.destination_id, 'kyoto')
        self.assertEqual(self.put({'items': []}, revision=1, mutation='remove-city').status_code, 200)
        expense.refresh_from_db()
        self.assertEqual(expense.destination_id, '')
        self.assertEqual(expense.amount, 7)
        self.assertIsNone(expense.plan_item_id)
        body['client_id'] = 'invalid'
        self.assertEqual(self.client.post(base + 'add/', data=json.dumps(body), content_type='application/json').status_code, 400)

    def test_multi_destination_route_and_overlapping_transfer_day(self):
        tokyo = {'id': 'tokyo', 'kind': 'destination', 'title': 'Tokyo', 'date': '2026-10-01', 'endDate': '2026-10-02'}
        kyoto = {'id': 'kyoto', 'kind': 'destination', 'title': 'Kyoto', 'date': '2026-10-02', 'endDate': '2026-10-03'}
        rail = {'id': 'rail', 'kind': 'booking', 'title': 'Shinkansen', 'category': 'Train', 'date': '2026-10-02', 'destinationId': 'tokyo', 'endDestinationId': 'kyoto'}
        restaurant = {'id': 'restaurant', 'kind': 'place', 'title': 'Dinner', 'destinationId': 'kyoto'}
        content = {'items': [tokyo, kyoto, rail, restaurant]}
        self.assertEqual(self.put(content).status_code, 200)
        self.assertEqual(self.client.get(self.url).json()['content'], content)
        reordered = {'items': [kyoto, tokyo, rail, restaurant]}
        self.assertEqual(self.put(reordered, revision=1, mutation='reorder').status_code, 200)
        self.assertEqual(self.client.get(self.url).json()['content']['items'][0]['id'], 'kyoto')
        self.assertEqual(self.put(reordered, revision=1, mutation='reorder').status_code, 200)
        self.assertEqual(self.put(content, revision=1, mutation='stale').status_code, 200)
        self.assertEqual(self.client.get(self.url).json()['content']['items'][0]['id'], 'kyoto')

    def test_destination_validation_and_trip_isolation(self):
        destination = {'id': 'tokyo', 'kind': 'destination', 'title': 'Tokyo', 'date': '2026-10-01', 'endDate': '2026-10-02'}
        for change in [{'date': ''}, {'endDate': '2026-09-30'}, {'endDate': '2026-10-04'}, {'destinationId': 'tokyo'}, {'paymentStatus': 'paid'}]:
            self.assertEqual(self.put({'items': [{**destination, **change}]}).status_code, 400)
        self.assertEqual(self.put({'items': [destination]}).status_code, 200)
        other = Trip.objects.create(destination='Other', start_date='2026-10-01', end_date='2026-10-03')
        content = {'items': [{'id': 'place', 'kind': 'place', 'title': 'Cafe', 'destinationId': 'tokyo'}]}
        self.assertEqual(self.put(content, url=f'/expenses/api/travel/trips/{other.id}/plan/').status_code, 400)
        content = {'items': [destination, {'id': 'hotel', 'kind': 'booking', 'category': 'Accommodation', 'title': 'Hotel', 'date': '2026-10-01', 'endDate': '2026-10-02', 'endDestinationId': 'tokyo'}]}
        self.assertEqual(self.put(content, revision=1, mutation='invalid-end').status_code, 400)

    def test_old_trip_returns_empty_plan_without_creating_row(self):
        self.assertEqual(self.client.get(self.url).json(), {'content': {'items': []}, 'revision': 0})
        self.assertFalse(TripPlan.objects.exists())

    def test_web_planner_page_and_browser_write(self):
        from django.test import Client
        client = Client(enforce_csrf_checks=True)
        page = client.get('/expenses/travel/')
        self.assertContains(page, 'Travel Planner')
        self.assertContains(page, 'Baidu Maps')
        self.assertContains(page, "'Overview','Itinerary','Places','Bookings','Preparation','Expenses'")
        payload = json.dumps({'content': self.content, 'revision': 0, 'mutation_id': 'web-save'})
        token = client.cookies['csrftoken'].value
        self.assertEqual(client.put(self.url, data=payload, content_type='application/json', HTTP_X_CSRFTOKEN=token).status_code, 200)

    def test_create_update_and_duplicate_retry(self):
        self.assertEqual(self.put().status_code, 200)
        self.assertEqual(self.put().json()['revision'], 1)
        self.assertEqual(self.put({'items': []}, 1, 'second').json()['revision'], 2)
        self.assertEqual(self.client.get(self.url).json()['content'], {'items': []})

    def test_stale_writer_cannot_overwrite(self):
        self.put()
        response = self.put({'items': []}, 0, 'other-device')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['content'], self.content)
        self.assertEqual(self.put({'items': []}, 0, 'first').status_code, 409)

    def test_trip_isolation_and_cascade(self):
        self.put()
        other = Trip.objects.create(destination='Osaka', start_date='2026-10-01', end_date='2026-10-03')
        self.assertEqual(self.client.get(f'/expenses/api/travel/trips/{other.id}/plan/').json()['revision'], 0)
        self.trip.delete()
        self.assertFalse(TripPlan.objects.exists())
        self.assertEqual(self.client.get(self.url).status_code, 404)
        self.assertEqual(self.put().status_code, 404)

    def test_rejects_bad_documents_and_links(self):
        cases = [None, [], {'items': 'bad'}, {'items': [1]}, {'items': [{'id':'x','kind':'unknown','title':'x'}]},
            {'items': [{'id':'x','kind':'place','title':'x','links':[{'purpose':'Map','label':'x','url':'javascript:alert(1)'}]}]},
            {'items': [{'id':'x','kind':'place','title':'x','links':[{'purpose':'Map','label':'x','url':'https://user:pass@example.com'}]}]},
            {'items': [{'id':'x','kind':'place','title':'x','links':[{'purpose':'Other','label':'x','url':'https://example.com:bad'}]}]},
            {'items': [{'id':'x','kind':'place','title':'x','links':[{'purpose':'Other','label':'x','url':'https://example.com:99999'}]}]},
            {'items': [{'id':'x','kind':'place','title':'x','date':'2026-02-31'}]},
            {'items': [{'id':'x','kind':'activity','title':'x','placeId':'missing'}]},
            {'items': [{'id':'x','kind':'place','title':'x'}, {'id':'x','kind':'place','title':'y'}]},
        ]
        for content in cases:
            with self.subTest(content=content):
                response = self.client.put(self.url, data=json.dumps({'content': content, 'revision':0, 'mutation_id':'x'}), content_type='application/json')
                self.assertEqual(response.status_code, 400)
        self.assertFalse(TripPlan.objects.exists())

    def test_linked_activity_and_cross_timezone_transport(self):
        content = {'items': [
            {'id':'p','kind':'place','title':'Shop'},
            {'id':'a','kind':'activity','title':'','placeId':'p','date':'2026-10-01'},
            {'id':'f','kind':'booking','title':'Flight','category':'Flight','date':'2026-10-02','endDate':'2026-10-01','timezone':'Asia/Tokyo','endTimezone':'America/Los_Angeles'},
        ]}
        self.assertEqual(self.put(content).status_code, 200)

    def test_accommodation_requires_checkout_after_checkin(self):
        self.assertEqual(self.put({'items':[{'id':'s','kind':'booking','title':'Hotel','category':'Accommodation','date':'2026-10-01','endDate':'2026-10-01'}]}).status_code, 400)

    def test_bad_envelope_is_rejected(self):
        for value in ['not json', 'null', '[]', '{"content":{"items":[]},"revision":true,"mutation_id":"x"}']:
            self.assertEqual(self.client.put(self.url, data=value, content_type='application/json').status_code, 400)

    def test_parent_create_is_idempotent_and_delete_by_client_is_safe(self):
        payload = {'destination':'Kyoto','start_date':'2026-10-01','end_date':'2026-10-02','client_id':'stable-offline-id'}
        first = self.client.post('/expenses/api/travel/trips/add/', data=json.dumps(payload), content_type='application/json')
        second = self.client.post('/expenses/api/travel/trips/add/', data=json.dumps(payload), content_type='application/json')
        self.assertEqual(first.json()['id'], second.json()['id'])
        listing = self.client.get('/expenses/api/travel/trips/').json()['trips']
        self.assertTrue(any(t['client_id'] == 'stable-offline-id' for t in listing))
        url = '/expenses/api/travel/trips/by-client/stable-offline-id/'
        self.assertEqual(self.client.delete(url).status_code, 200)
        self.assertEqual(self.client.delete(url).status_code, 200)
        self.assertFalse(Trip.objects.filter(client_id='stable-offline-id').exists())



class TravelDestinationMigrationTests(TestCase):
    def backfill(self):
        from django.apps import apps
        from importlib import import_module
        migration = import_module('expenses.migrations.0009_backfill_travel_destinations')
        migration.backfill_destinations(apps, None)

    def test_legacy_trip_becomes_one_destination_without_changing_ledger(self):
        trip = Trip.objects.create(destination='Europe', start_date='2026-04-02', end_date='2026-04-10')
        expense = TravelExpense.objects.create(trip=trip, name='Rail ticket', amount=81.2,
            currency='USD', date='2026-03-01', category='Transportation', notes='Original notes')
        before = {key: value for key, value in TravelExpense.objects.values().get().items()
                  if key != 'destination_id'}
        self.backfill()
        plan = TripPlan.objects.get(trip=trip)
        visit = plan.content['items'][0]
        self.assertEqual((visit['title'], visit['date'], visit['endDate']), ('Europe', '2026-04-02', '2026-04-10'))
        self.assertEqual(plan.revision, 1)
        expense.refresh_from_db()
        self.assertEqual(expense.destination_id, visit['id'])
        after = {key: value for key, value in TravelExpense.objects.values().get().items()
                 if key != 'destination_id'}
        self.assertEqual(before, after)
        self.backfill()
        self.assertEqual(TripPlan.objects.count(), 1)
        self.assertEqual(TravelExpense.objects.count(), 1)
        self.assertEqual(TripPlan.objects.get().revision, 1)

    def test_existing_plan_backfills_linked_city_without_guessing_standalone_city(self):
        trip = Trip.objects.create(destination='Japan', start_date='2026-10-01', end_date='2026-10-03')
        items = [
            {'id': 'kyoto', 'kind': 'destination', 'title': 'Kyoto'},
            {'id': 'cafe', 'kind': 'place', 'title': 'Cafe', 'destinationId': 'kyoto'},
            {'id': 'breakfast', 'kind': 'activity', 'title': 'Breakfast', 'placeId': 'cafe'},
        ]
        TripPlan.objects.create(trip=trip, content={'items': items}, revision=7)
        linked = TravelExpense.objects.create(trip=trip, plan_item_id='breakfast', name='Breakfast',
            amount=8, currency='USD', date='2026-10-01', category='Food & Drinks')
        standalone = TravelExpense.objects.create(trip=trip, name='Water', amount=2,
            currency='USD', date='2026-10-01', category='Other')
        self.backfill()
        linked.refresh_from_db()
        standalone.refresh_from_db()
        self.assertEqual(linked.destination_id, 'kyoto')
        self.assertEqual(standalone.destination_id, '')
        self.assertEqual(TripPlan.objects.get().content, {'items': items})
        self.assertEqual(TripPlan.objects.get().revision, 7)
