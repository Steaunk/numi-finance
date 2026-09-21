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
        self.assertEqual(self.client.get(self.url).json(), {'content': {'items': []}, 'revision': 0, 'payment_ids': {}})
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


class BookingPaymentTests(TestCase):
    def setUp(self):
        from unittest.mock import patch
        from core.services import FALLBACK_RATES
        self.rate_patch = patch('expenses.planning.get_rates', return_value=FALLBACK_RATES)
        self.rate_patch.start()
        self.addCleanup(self.rate_patch.stop)
        self.trip = Trip.objects.create(destination='Kyoto', start_date='2026-10-01', end_date='2026-10-03')
        self.url = f'/expenses/api/travel/trips/{self.trip.id}/plan/'
        self.booking = {'id':'hotel', 'kind':'booking', 'title':'Riverside hotel', 'category':'Accommodation',
            'date':'2026-10-01', 'endDate':'2026-10-03', 'status':'confirmed', 'amount':'200', 'currency':'SGD',
            'paymentStatus':'paid', 'paidDate':'2026-09-21', 'expenseClientId':'payment-hotel', 'expenseCategory':'Accommodation'}

    def put(self, items=None, revision=0, mutation='first'):
        return self.client.put(self.url, data=json.dumps({'content':{'items':items if items is not None else [self.booking]},
            'revision':revision, 'mutation_id':mutation}), content_type='application/json')

    def test_paid_booking_creates_one_expense_and_retry_is_idempotent(self):
        from .models import TravelExpense
        self.assertEqual(self.put().status_code, 200)
        expense = TravelExpense.objects.get()
        self.assertEqual((expense.amount, expense.name, expense.plan_item_id), (200, 'Riverside hotel', 'hotel'))
        self.assertEqual(str(expense.date), '2026-09-21')
        self.assertEqual(self.put().json()['payment_ids'], {'payment-hotel':expense.id})
        self.assertEqual(TravelExpense.objects.count(), 1)
        self.assertEqual(self.put([{**self.booking,'title':'New name','amount':'240'}], 1, 'edit').status_code, 200)
        expense.refresh_from_db()
        self.assertEqual((expense.name, expense.amount), ('New name', 240))
        self.assertEqual(TravelExpense.objects.count(), 1)

    def test_unpaid_to_paid_and_payment_removal(self):
        from .models import TravelExpense
        unpaid = {**self.booking,'paymentStatus':'unpaid'}
        self.assertEqual(self.put([unpaid]).status_code, 200)
        self.assertFalse(TravelExpense.objects.exists())
        self.assertEqual(self.put(revision=1, mutation='pay').status_code, 200)
        self.assertEqual(TravelExpense.objects.count(), 1)
        self.assertEqual(self.put([unpaid],2,'remove-payment').status_code, 200)
        self.assertFalse(TravelExpense.objects.exists())
        self.assertEqual(len(TripPlan.objects.get().content['items']), 1)

    def test_cancel_and_delete_booking_keep_payment(self):
        from .models import TravelExpense
        self.put()
        self.put([{**self.booking,'status':'cancelled'}],1,'cancel')
        self.assertEqual(TravelExpense.objects.count(), 1)
        self.put([],2,'delete')
        expense=TravelExpense.objects.get()
        self.assertIsNone(expense.plan_item_id)
        self.assertEqual(expense.amount, 200)

    def test_existing_expense_adopted_without_copy_and_late_create_retry_safe(self):
        from .models import TravelExpense
        expense = TravelExpense.objects.create(trip=self.trip, client_id='payment-hotel', amount=200,
            currency='SGD', date='2026-09-21', category='Accommodation', name='Riverside hotel')
        self.assertEqual(self.put().status_code, 200)
        self.assertEqual(TravelExpense.objects.get().id, expense.id)
        url=f'/expenses/api/travel/trips/{self.trip.id}/expenses/add/'
        self.assertEqual(self.client.post(url,data=json.dumps({'client_id':'payment-hotel','name':'stale'}),content_type='application/json').json()['id'],expense.id)
        self.assertEqual(TravelExpense.objects.get().name,'Riverside hotel')

    def test_cross_trip_identity_and_duplicate_links_roll_back(self):
        from .models import TravelExpense
        other=Trip.objects.create(destination='Osaka',start_date='2026-10-01',end_date='2026-10-03')
        TravelExpense.objects.create(trip=other,client_id='payment-hotel',amount=200,currency='SGD',date='2026-09-21',category='Accommodation',name='Other')
        self.assertEqual(self.put().status_code,400)
        self.assertFalse(TripPlan.objects.exists())
        self.assertEqual(self.put([self.booking,{**self.booking,'id':'second'}]).status_code,400)
        self.assertFalse(TripPlan.objects.exists())

    def test_conflict_and_invalid_amount_do_not_touch_payment(self):
        from .models import TravelExpense
        self.put()
        self.assertEqual(self.put([{**self.booking,'amount':'999'}],0,'stale').status_code,409)
        self.assertEqual(TravelExpense.objects.get().amount,200)
        for value in ['0','-1','NaN','Infinity','bad']:
            self.assertEqual(self.put([{**self.booking,'amount':value}],1,value).status_code,400)
        self.assertEqual(TravelExpense.objects.get().amount,200)

    def test_legacy_direct_edit_and_delete_cannot_desynchronize_booking(self):
        from .models import TravelExpense
        self.put()
        expense=TravelExpense.objects.get()
        url=f'/expenses/api/travel/trips/{self.trip.id}/expenses/{expense.id}/'
        self.assertEqual(self.client.put(url,data='{}',content_type='application/json').status_code,409)
        self.assertEqual(self.client.delete(url+'delete/').status_code,409)
        self.assertTrue(TravelExpense.objects.filter(pk=expense.id).exists())

    def test_flights_and_linked_sightseeing_activities_share_the_payment_flow(self):
        from .models import TravelExpense
        flight = {**self.booking, 'id':'flight','category':'Flight','expenseClientId':'flight-pay','expenseCategory':'Transportation'}
        place = {'id':'museum','kind':'place','title':'Museum','category':'Sightseeing'}
        activity = {'id':'visit','kind':'activity','placeId':'museum','date':'2026-10-01',
            'paymentStatus':'paid','amount':'30','currency':'SGD','paidDate':'2026-09-21',
            'expenseClientId':'ticket-pay','expenseCategory':'Sightseeing'}
        self.assertEqual(self.put([flight,place,activity]).status_code,200)
        ticket=TravelExpense.objects.get(client_id='ticket-pay')
        self.assertEqual((ticket.name,ticket.category),('Museum','Sightseeing'))
        self.assertEqual(TravelExpense.objects.get(client_id='flight-pay').category,'Transportation')
        self.assertEqual(self.put([flight,{**place,'title':'Art Museum'},activity],1,'rename').status_code,200)
        ticket.refresh_from_db()
        self.assertEqual(ticket.name,'Art Museum')

    def test_older_app_remote_id_alias_adopts_new_server_identity_without_copy(self):
        from .models import TravelExpense
        expense=TravelExpense.objects.create(trip=self.trip,client_id='server-stable-identity',amount=200,currency='SGD',date='2026-09-21',category='Accommodation',name='Old client payment')
        booking={**self.booking,'expenseClientId':f'remote-{expense.id}'}
        result=self.put([booking])
        self.assertEqual(result.status_code,200)
        self.assertEqual(result.json()['payment_ids'][booking['expenseClientId']],expense.id)
        self.assertEqual(TravelExpense.objects.count(),1)
        expense.refresh_from_db()
        self.assertEqual(expense.client_id,'server-stable-identity')
