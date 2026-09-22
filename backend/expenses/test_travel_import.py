import json
from unittest.mock import Mock, patch
from django.test import SimpleTestCase
from .travel_import import analyze, fetch_page, provider, public_address


class TravelImportTests(SimpleTestCase):
    @patch('expenses.travel_import.fetch_page')
    def test_listing_metadata_and_link_dates_are_draft_only(self, fetch):
        url = 'https://www.airbnb.com/rooms/123?check_in=2026-10-07&check_out=2026-10-09'
        fetch.return_value = (url, '''<script type="application/ld+json">{"@type":"VacationRental","name":"Ocean house", "address":{"streetAddress":"1 Beach St","addressLocality":"Kamakura","addressCountry":"JP"},"offers":{"price":999},"checkinTime":"15:00"}</script>''')
        draft = analyze('Ocean house\n' + url, url)
        self.assertEqual(draft['title'], 'Ocean house')
        self.assertEqual(draft['address'], '1 Beach St, Kamakura, JP')
        self.assertEqual((draft['date'], draft['endDate']), ('2026-10-07', '2026-10-09'))
        self.assertEqual(draft['category'], 'Accommodation')
        for key in ('amount', 'paymentStatus', 'confirmation', 'status', 'time', 'endTime'):
            self.assertNotIn(key, draft)
        self.assertEqual(draft['links'][0]['url'], url)

    @patch('expenses.travel_import.fetch_page')
    def test_maps_short_link_and_named_url(self, fetch):
        url = 'https://maps.app.goo.gl/example'
        fetch.return_value = ('https://www.google.com/maps/place/Kamakura+Prince+Hotel/@35,139,10z', '<title>Google Maps</title>')
        draft = analyze(url, url)
        self.assertEqual(draft['title'], 'Kamakura Prince Hotel')
        self.assertEqual(draft['links'][0]['purpose'], 'Map')
        self.assertEqual(draft['date'], '')

    @patch('expenses.travel_import.fetch_page')
    def test_trip_hotel_graph_and_compact_dates(self, fetch):
        url = 'https://sg.trip.com/hotels/example/?checkin=20261007&checkout=20261009'
        fetch.return_value = (url, '<script type="application/ld+json">{"@graph":[{"@type":"WebPage"},{"@type":["Hotel","LocalBusiness"],"name":"Prince Hotel"}]}</script>')
        draft = analyze(url, url)
        self.assertEqual(draft['title'], 'Prince Hotel')
        self.assertEqual(draft['date'], '2026-10-07')
        self.assertEqual(draft['category'], 'Accommodation')

    @patch('expenses.travel_import.fetch_page')
    def test_trip_server_rendered_accessible_hotel_details(self, fetch):
        url = 'https://www.trip.com/hotels/kamakura-hotel-detail-1679082/kamakura-prince-hotel/'
        fetch.return_value = (url, '<h1 class="hotelNameRow_hotelOverview_name__Racfv" aria-label="Kamakura Prince Hotel">Kamakura Prince Hotel</h1><span class="hotelAddressBar_hotelOverview_addressText__flPOV" aria-label="1 Chome-2-18 Shichirigahamahigashi, Kamakura, Japan"></span>')
        draft = analyze(url, url)
        self.assertEqual(draft['title'], 'Kamakura Prince Hotel')
        self.assertIn('Shichirigahamahigashi', draft['address'])

    @patch('expenses.travel_import.fetch_page', side_effect=ValueError('login required'))
    def test_unavailable_page_keeps_share_text(self, _):
        url = 'https://www.airbnb.com/rooms/123'
        draft = analyze('A place by the beach\n' + url, url)
        self.assertEqual(draft['title'], 'A place by the beach')
        self.assertTrue(draft['warning'])
        self.assertEqual(draft['date'], '')
        self.assertIn(url, draft['notes'])

    @patch('expenses.travel_import.fetch_page')
    def test_og_title_is_not_discarded_for_provider_suffix(self, fetch):
        url = 'https://www.airbnb.com/rooms/123'
        fetch.return_value = (url, '<meta property="og:title" content="Ocean house - Airbnb">')
        self.assertEqual(analyze(url, url)['title'], 'Ocean house - Airbnb')

    def test_rejects_lookalikes_credentials_and_private_hosts(self):
        for url in ('https://airbnb.com.evil.test/rooms/1', 'https://127.0.0.1/', 'file:///etc/passwd', 'https://user:password@airbnb.com/', 'https://airbnb.com:8443/'):
            self.assertEqual(provider(url), '')
        for ip in ('127.0.0.1', '10.0.0.1', '169.254.169.254', '::1', '::ffff:127.0.0.1'):
            with patch('expenses.travel_import.socket.getaddrinfo', return_value=[(None, None, None, None, (ip, 443))]):
                with self.assertRaises(ValueError):
                    public_address('www.airbnb.com')

    @patch('expenses.travel_import.public_address', return_value='8.8.8.8')
    @patch('expenses.travel_import.urllib3.HTTPSConnectionPool')
    def test_redirect_is_revalidated_and_connection_uses_vetted_ip(self, pool, _):
        response = Mock(status=302, headers={'Location': 'https://127.0.0.1/private'})
        pool.return_value.urlopen.return_value = response
        with self.assertRaises(ValueError):
            fetch_page('https://abnb.me/example')
        self.assertEqual(pool.call_count, 1)
        self.assertEqual(pool.call_args.args[0], '8.8.8.8')
        self.assertEqual(pool.call_args.kwargs['server_hostname'], 'abnb.me')
        self.assertNotIn('Authorization', pool.return_value.urlopen.call_args.kwargs['headers'])
        response.close.assert_called_once()

    @patch('expenses.travel_import.fetch_page')
    def test_preview_endpoint_no_writes_and_bad_payloads(self, fetch):
        url = 'https://www.google.com/maps/search/?api=1&query=Kamakura'
        fetch.return_value = (url, '')
        response = self.client.post('/expenses/api/travel/import-preview/', data=json.dumps({'text': url, 'url': url}), content_type='application/json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['title'], 'Kamakura')
        self.assertEqual(response['Cache-Control'], 'no-store')
        for payload in ({'url': 'http://localhost/'}, {'text': 'x' * 10001, 'url': url}, [], None):
            response = self.client.post('/expenses/api/travel/import-preview/', data=json.dumps(payload), content_type='application/json')
            self.assertEqual(response.status_code, 400)

    @patch('expenses.travel_import.fetch_page')
    def test_trip_multi_leg_reservations_keep_local_times_and_no_payment(self, fetch):
        url = 'https://www.trip.com/flights/itinerary/example'
        documents = {'@graph': [
            {'@type': 'FlightReservation', 'reservationStatus': 'ReservationConfirmed', 'reservationFor': {
                '@type': 'Flight', 'flightNumber': 'SQ638', 'departureAirport': {'name': 'SIN'}, 'arrivalAirport': {'name': 'NRT'},
                'departureTime': '2026-10-06T23:55:00+08:00', 'arrivalTime': '2026-10-07T07:30:00+09:00'}},
            {'@type': 'TrainTrip', 'trainNumber': 'NEX21', 'departureStation': {'name': 'Narita Airport'},
             'arrivalStation': {'name': 'Tokyo'}, 'departureTime': '2026-10-07T09:00:00+09:00'}]}
        fetch.return_value = (url, '<script type="application/ld+json">' + json.dumps(documents) + '</script>')
        items = analyze(url, url)['items']
        self.assertEqual([i['category'] for i in items], ['Flight', 'Train'])
        self.assertEqual((items[0]['time'], items[0]['endTime']), ('23:55', '07:30'))
        self.assertEqual((items[0]['timezone'], items[0]['endTimezone']), ('UTC+08:00', 'UTC+09:00'))
        self.assertEqual(items[1]['address'], 'Narita Airport')
        self.assertNotIn('paymentStatus', items[0])

    def test_pasted_museum_and_multi_leg_text_without_a_link(self):
        draft = analyze('Venue: 草間彌生美術館 - YAYOI KUSAMA MUSEUM\nDate/time: 10 October 2026 11:00', '')
        self.assertEqual(draft['items'][0]['kind'], 'activity')
        self.assertEqual(draft['items'][0]['date'], '2026-10-10')
        self.assertEqual(draft['items'][0]['time'], '11:00')
        text = 'Flight: SQ638\nFrom: SIN\nTo: NRT\nDeparture: 2026-10-06 23:55\nArrival: 2026-10-07 07:30\n\nTrain: NEX21\nFrom: NRT\nTo: Tokyo\nDeparture: 7 October 09:00'
        items = analyze(text, '')['items']
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]['endDate'], '2026-10-07')
        self.assertEqual(items[1]['date'], '')  # Missing year is not guessed.

    @patch('expenses.travel_import.fetch_page')
    def test_trip_route_places_are_individual_candidates(self, fetch):
        url = 'https://www.trip.com/travel-guide/example'
        fetch.return_value = (url, '<script type="application/ld+json">{"@type":"TouristTrip","itinerary":{"@type":"ItemList","itemListElement":[{"@type":"Place","name":"Tokyo"},{"@type":"Place","name":"Kamakura"}]}}</script>')
        self.assertEqual([i['title'] for i in analyze(url, url)['items']], ['Tokyo', 'Kamakura'])
