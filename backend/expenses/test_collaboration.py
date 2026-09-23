import json
from django.utils import timezone
from django.test import TestCase, Client
from .models import Trip, TripPlan, TripInvite, TravelExpense, TripPlanChange
from .collaboration import save_document, merge_content, PlanConflict


class CollaborationTests(TestCase):
    def setUp(self):
        self.trip = Trip.objects.create(destination='Tokyo', start_date='2026-10-03', end_date='2026-10-12')
        self.trip.refresh_from_db()
        self.base = f'/expenses/api/travel/trips/{self.trip.id}/collaboration/'
        self.shared = f'/travel/shared/{self.trip.id}/'
        self.content = {'items': [
            {'id': 'me', 'kind': 'person', 'title': 'Me'},
            {'id': 'nyt', 'kind': 'person', 'title': 'NYT'},
            {'id': 'visit', 'kind': 'activity', 'title': 'Museum', 'notes': 'Original'},
            {'id': 'flight', 'kind': 'booking', 'title': 'Flight', 'category': 'Flight', 'date': '2026-10-06',
             'participantIds': ['nyt'],
             'notes': 'Private original ledger note'}]}
        save_document(self.trip, self.content, 0, 'seed', 'Owner')
        TravelExpense.objects.create(trip=self.trip, plan_item_ids=['flight'], amount=100, currency='USD', date='2026-09-01', category='Transportation', name='Flight', notes='Private ledger note')

    def post(self, url, body, client=None, **kwargs):
        return (client or self.client).post(url, json.dumps(body), content_type='application/json', **kwargs)

    def guest(self, role='editor', csrf=False):
        response = self.post(self.base+'invites/', {'name': 'NYT', 'role': role, 'person_id': 'nyt'})
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertNotIn('token_hash', data)
        token = data['url'].split('#invite=')[1]
        self.assertNotEqual(TripInvite.objects.get(id=data['id']).token_hash, token)
        guest = Client(enforce_csrf_checks=csrf)
        guest.get(self.shared)
        header = {'HTTP_X_CSRFTOKEN': guest.cookies['csrftoken'].value} if csrf else {}
        self.assertEqual(self.post(self.shared+'session/', {'token': token}, guest, **header).status_code, 200)
        return guest, data['id']

    def edit(self, client, operations, revision=1, mutation='edit'):
        return self.post(self.shared+'data/', {'operations': operations, 'revision': revision, 'mutation_id': mutation}, client)

    def test_map_preview_and_pin_edits_require_trip_access(self):
        url = 'https://www.google.com/maps/search/?api=1&query=35,139'
        self.assertEqual(self.post(self.shared+'map-preview/', {'url': url}).status_code, 403)
        guest, invite_id = self.guest()
        response = self.post(self.shared+'map-preview/', {'url': url}, guest)
        self.assertEqual(response.json(), {'latitude': '35.0', 'longitude': '139.0'})
        self.assertEqual(self.post(self.shared+'map-preview/', {'url': 'https://127.0.0.1'}, guest).status_code, 400)
        self.assertEqual(TripPlan.objects.get(trip=self.trip).revision, 1)
        changed = self.edit(guest, [{'id': 'visit', 'changes': response.json()}])
        self.assertEqual(changed.status_code, 200)
        self.assertEqual(changed.json()['content']['items'][2]['latitude'], '35.0')
        viewer, _ = self.guest('viewer')
        self.assertEqual(self.edit(viewer, [{'id': 'visit', 'changes': {'latitude': '36', 'longitude': '140'}}], revision=2).status_code, 403)
        TripInvite.objects.filter(id=invite_id).update(revoked_at=timezone.now())
        self.assertEqual(self.post(self.shared+'map-preview/', {'url': url}, guest).status_code, 403)

    def test_private_fields_never_leave_shared_api_or_history(self):
        guest, _ = self.guest()
        for path in ['data/', 'history/']:
            response = guest.get(self.shared+path)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response['Cache-Control'], 'no-store')
            for word in ['expenseClientId', 'paymentStatus', 'paidDate', 'payment_ids', '"amount"', '"currency"']:
                self.assertNotIn(word, response.content.decode())
        denied = self.edit(guest, [{'id': 'flight', 'changes': {'amount': '900'}}])
        self.assertEqual(denied.status_code, 400)
        self.assertEqual(TravelExpense.objects.get().amount, 100)

    def test_participants_default_all_subset_and_archive(self):
        guest, _ = self.guest()
        response = self.edit(guest, [{'id': 'visit', 'changes': {'participantIds': ['me']}}])
        self.assertEqual(response.status_code, 200)
        for ids in [['unknown'], ['nyt','nyt'], 'nyt', [None]]:
            self.assertEqual(self.edit(guest, [{'id': 'visit', 'changes': {'participantIds': ids}}],2,'bad').status_code,400)
        self.assertEqual(self.edit(guest,[{'id':'nyt','delete':True}],2,'delete-person').status_code,400)
        self.assertEqual(self.edit(guest,[{'id':'nyt','changes':{'status':'cancelled'}}],2,'archive').status_code,200)

    def test_session_is_trip_scoped_viewer_revoked_and_csrf_protected(self):
        guest, invite_id = self.guest('viewer')
        self.assertEqual(self.edit(guest,[{'id':'visit','changes':{'title':'Changed'}}]).status_code,403)
        other = Trip.objects.create(destination='Other', start_date='2026-10-01', end_date='2026-10-02')
        self.assertEqual(guest.get(f'/travel/shared/{other.id}/data/').status_code,403)
        self.assertEqual(Client().get(self.shared+'data/').status_code,403)
        self.client.delete(self.base+'invites/',json.dumps({'id':invite_id}),content_type='application/json')
        self.assertEqual(guest.get(self.shared+'data/').status_code,403)
        secure,_=self.guest(csrf=True)
        body={'operations':[{'id':'visit','changes':{'title':'CSRF'}}],'revision':1,'mutation_id':'csrf'}
        self.assertEqual(self.post(self.shared+'data/',body,secure).status_code,403)
        self.assertEqual(self.post(self.shared+'data/',body,secure,HTTP_X_CSRFTOKEN=secure.cookies['csrftoken'].value).status_code,200)

    def test_disjoint_edits_merge_and_same_field_conflicts(self):
        guest,_=self.guest()
        self.assertEqual(self.edit(guest,[{'id':'visit','changes':{'title':'Art museum'}}]).status_code,200)
        self.assertEqual(self.edit(guest,[{'id':'visit','changes':{'notes':'Open at noon'}}],mutation='notes').status_code,200)
        response=self.edit(guest,[{'id':'visit','changes':{'title':'Another museum'}}],mutation='conflict')
        self.assertEqual(response.status_code,409)
        self.assertEqual(response.json()['conflicts'][0]['field'],'title')
        item=TripPlan.objects.get(trip=self.trip).content['items'][2]
        self.assertEqual((item['title'],item['notes']),('Art museum','Open at noon'))

    def test_retries_after_later_edits_do_not_reapply_mutations(self):
        guest,_=self.guest()
        ops=[{'id':'visit','changes':{'title':'First'}}]
        first=self.edit(guest,ops).json()
        self.edit(guest,[{'id':'visit','changes':{'title':'Second'}}],revision=2,mutation='second')
        retry=self.edit(guest,ops)
        self.assertEqual(retry.status_code,200)
        self.assertEqual(retry.json()['revision'],first['revision'])
        self.assertEqual(TripPlan.objects.get().content['items'][2]['title'],'Second')
        self.assertEqual(self.edit(guest,[{'id':'visit','delete':True}]).status_code,409)

    def test_shared_edits_preserve_ledger_and_delete_keeps_payment(self):
        guest,_=self.guest()
        before=TravelExpense.objects.values().get()
        self.assertEqual(self.edit(guest,[{'id':'flight','changes':{'title':'NYT flight','notes':'Shared new note'}}]).status_code,200)
        self.assertEqual(TravelExpense.objects.values().get(),before)
        self.assertEqual(self.edit(guest,[{'id':'flight','delete':True}],2,'remove').status_code,200)
        after=TravelExpense.objects.values().get()
        self.assertEqual(after,dict(before,plan_item_ids=[]))
        self.assertEqual(TripPlanChange.objects.latest('revision').actor,'NYT')

    def test_offline_owner_document_merge_and_scoped_conflict_choice(self):
        guest,_=self.guest()
        self.edit(guest,[{'id':'visit','changes':{'title':'Remote','notes':'Remote note'}}])
        local=json.loads(json.dumps(self.content));local['items'][2]['title']='Local'
        local['items'][3]['time']='09:15'
        with self.assertRaises(PlanConflict):
            save_document(self.trip,local,1,'owner','Owner')
        result=save_document(self.trip,local,1,'resolve','Owner',choice='local',expected_revision=2)
        item=result['content']['items'][2]
        self.assertEqual((item['title'],item['notes']),('Local','Remote note'))
        self.assertEqual(result['content']['items'][3]['time'],'09:15')
        with self.assertRaises(PlanConflict):
            save_document(self.trip,local,1,'late','Owner',choice='local',expected_revision=2)

    def test_delete_edit_conflict_and_unseen_additions_survive(self):
        guest,_=self.guest()
        self.edit(guest,[{'id':'visit','changes':{'notes':'new'}}])
        self.assertEqual(self.edit(guest,[{'id':'visit','delete':True}],mutation='delete').status_code,409)
        empty={'items':[]}
        self.assertEqual(merge_content(empty,empty,self.content),self.content)

    def test_history_restore_changes_itinerary_only_even_for_owner(self):
        history=self.client.get(self.base+'history/').json()['changes']
        old=next(i for i in history[0]['content']['items'] if i['id']=='flight')
        self.assertNotIn('amount',old)
        before=TravelExpense.objects.values().get()
        response=self.post(self.base+'data/',{'revision':1,'mutation_id':'owner-restore','operations':[
            {'id':'flight','replace':True,'changes':{**old,'title':'Restored public name','notes':'Restored public notes'}}]})
        self.assertEqual(response.status_code,200)
        self.assertEqual(TravelExpense.objects.values().get(),before)
        self.assertNotIn('paymentStatus', TripPlan.objects.get().content['items'][3])

    def test_expired_invitation_rejects_existing_session(self):
        from django.utils import timezone
        from datetime import timedelta
        guest,invite_id=self.guest()
        TripInvite.objects.filter(id=invite_id).update(expires_at=timezone.now()-timedelta(seconds=1))
        self.assertEqual(guest.get(self.shared+'data/').status_code,403)
        self.assertEqual(guest.get(self.shared+'history/').status_code,403)
        self.assertEqual(self.edit(guest,[{'id':'visit','changes':{'title':'Expired'}}]).status_code,403)
