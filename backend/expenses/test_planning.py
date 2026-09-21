import json
from django.test import TestCase
from .models import Trip, TripPlan


class TripPlanTests(TestCase):
    def setUp(self):
        self.trip = Trip.objects.create(destination='Tokyo', start_date='2026-10-01', end_date='2026-10-03')
        self.url = f'/expenses/api/travel/trips/{self.trip.id}/plan/'
        self.content = {'items': [{'id': 'place1', 'kind': 'place', 'title': 'Coffee', 'links': [
            {'purpose': 'Map', 'label': 'Find it', 'url': 'https://maps.app.goo.gl/example'}]}]}

    def put(self, content=None, revision=0, mutation='first', url=None):
        return self.client.put(url or self.url, data=json.dumps({'content': self.content if content is None else content,
            'revision': revision, 'mutation_id': mutation}), content_type='application/json')

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
        self.assertEqual(response.status_code, 409)
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
