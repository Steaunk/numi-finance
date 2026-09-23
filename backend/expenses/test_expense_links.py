import json
from unittest.mock import patch
from django.test import TestCase
from core.services import FALLBACK_RATES
from .models import Trip, TripPlan, TravelExpense
from .collaboration import save_document


class ExpenseLinkTests(TestCase):
    def setUp(self):
        self.trip = Trip.objects.create(destination='Tokyo', start_date='2026-10-01', end_date='2026-10-05')
        self.trip.refresh_from_db()
        self.items = [{'id': name, 'kind': 'activity', 'title': name, 'category': 'Sightseeing'} for name in ['museum', 'park']]
        save_document(self.trip, {'items': self.items}, 0, 'seed', 'Owner')
        self.url = f'/expenses/api/travel/trips/{self.trip.id}/expenses/'
        self.data = {'amount': 2200, 'currency': 'JPY', 'date': '2026-09-21', 'category': 'Sightseeing', 'name': 'Tickets', 'plan_item_ids': ['museum', 'park'], 'client_id': 'ticket'}
        self.patch = patch('expenses.views.get_rates', return_value=FALLBACK_RATES)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def post(self, data=None):
        return self.client.post(self.url+'add/', json.dumps(data or self.data), content_type='application/json')

    def test_many_to_many_counts_each_expense_once_and_retry_is_safe(self):
        self.assertEqual(self.post().status_code, 201)
        self.assertEqual(self.post().status_code, 200)
        self.assertEqual(self.post({**self.data, 'client_id': 'ticket2', 'name': 'Audio guides'}).status_code, 201)
        expenses = TravelExpense.objects.all()
        self.assertEqual(expenses.count(), 2)
        self.assertTrue(all(e.plan_item_ids == ['museum', 'park'] for e in expenses))
        listed = self.client.get(self.url).json()
        self.assertEqual(len(listed['expenses']), 2)
        self.assertEqual(listed['total_converted'], round(sum(e.amount_sgd for e in expenses), 2))
        self.assertEqual(TripPlan.objects.get().content, {'items': self.items})

    def test_edit_delete_and_unlink_do_not_change_itinerary(self):
        self.post()
        expense = TravelExpense.objects.get()
        url = self.url+f'{expense.id}/'
        self.assertEqual(self.client.put(url, json.dumps({**self.data, 'amount': 2500}), content_type='application/json').status_code, 200)
        self.assertEqual(self.client.put(url+'links/', json.dumps({'plan_item_ids': []}), content_type='application/json').status_code, 200)
        expense.refresh_from_db()
        self.assertEqual((expense.amount, expense.plan_item_ids), (2500, []))
        self.assertEqual(self.client.delete(url+'delete/').status_code, 200)
        self.assertEqual(TripPlan.objects.get().content, {'items': self.items})

    def test_removing_arrangement_detaches_only_that_link_and_preserves_money(self):
        self.post()
        expense = TravelExpense.objects.values().get()
        save_document(self.trip, {'items': [self.items[1]]}, 1, 'remove', 'Owner')
        self.assertEqual(TravelExpense.objects.values().get(), {**expense, 'plan_item_ids': ['park']})
        save_document(self.trip, {'items': []}, 2, 'remove-all', 'Owner')
        self.assertEqual(TravelExpense.objects.get().amount, 2200)
        self.assertEqual(TravelExpense.objects.get().plan_item_ids, [])

    def test_foreign_missing_duplicate_or_wrong_kind_links_are_rejected(self):
        for ids in [['foreign'], ['museum', 'museum'], 'museum', [None], [{}]]:
            self.assertEqual(self.post({**self.data, 'plan_item_ids': ids}).status_code, 400)
        self.assertFalse(TravelExpense.objects.exists())

    def test_activity_type_is_editable_and_plan_rejects_money(self):
        result = save_document(self.trip, {'items': [{**self.items[0], 'category': 'Restaurant'}, self.items[1]]}, 1, 'category', 'Owner')
        self.assertEqual(result['content']['items'][0]['category'], 'Restaurant')
        with self.assertRaises(ValueError):
            save_document(self.trip, {'items': [{**self.items[0], 'amount': '50'}]}, 2, 'money', 'Owner')
        self.assertFalse(TravelExpense.objects.exists())


class ExpenseLinkMigrationTests(TestCase):
    def test_migration_preserves_ledger_and_cleans_current_and_historical_plans(self):
        import importlib
        from django.apps import apps
        from .models import TripPlanChange
        trip = Trip.objects.create(destination='Tokyo', start_date='2026-10-01', end_date='2026-10-02')
        item = {'id': 'museum', 'kind': 'activity', 'title': 'Museum', 'category': 'Activity', 'amount': '2200', 'currency': 'JPY', 'paymentStatus': 'paid', 'expenseCategory': 'Sightseeing'}
        plan = TripPlan.objects.create(trip=trip, content={'items': [item]}, revision=3)
        TripPlanChange.objects.create(trip=trip, content={'items': [item]}, revision=3)
        TravelExpense.objects.create(trip=trip, plan_item_id='museum', name='Ticket', amount=2200, currency='JPY', date='2026-09-23', category='Sightseeing')
        before = TravelExpense.objects.values().get()
        importlib.import_module('expenses.migrations.0012_expense_itinerary_links').forward(apps, None)
        plan.refresh_from_db()
        self.assertEqual(TravelExpense.objects.values().get(), {**before, 'plan_item_id': None, 'plan_item_ids': ['museum']})
        self.assertEqual(plan.revision, 4)
        for content in [plan.content, *TripPlanChange.objects.values_list('content', flat=True)]:
            self.assertEqual(content['items'][0]['category'], 'Sightseeing')
            self.assertNotIn('amount', content['items'][0])
            self.assertNotIn('paymentStatus', content['items'][0])
