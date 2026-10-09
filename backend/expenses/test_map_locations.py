from django.test import SimpleTestCase
from .map_locations import google_point
from .planning import validate_content
from .travel_import import structured_place


class MapLocationTests(SimpleTestCase):
    def test_place_pin_is_not_camera(self):
        url = 'https://www.google.com/maps/place/Pacific/@35.304,139.511,17z/data=!3m1!4b1!8m2!3d35.3044277!4d139.5135768'
        self.assertEqual(google_point(url), {'latitude': '35.3044277', 'longitude': '139.5135768'})
        for url in ['https://www.google.com/maps/@35,139,14z',
                    'https://www.google.com/maps?ll=35,139',
                    'https://www.google.com/maps/dir/?q=35,139',
                    'https://evil.example/maps?q=35,139',
                    'https://www.google.com/maps?q=91,139',
                    'https://www.google.com/maps/data=!3d35!4d139!3d36!4d140']:
            self.assertEqual(google_point(url), {}, url)
        self.assertEqual(google_point('https://www.google.com/maps/search/?api=1&query=35%2C139'), {'latitude': '35.0', 'longitude': '139.0'})

    def test_metadata_coordinates(self):
        result = structured_place([{'@type': 'Hotel', 'name': 'Stay', 'geo': {'latitude': 35, 'longitude': 139}}])
        self.assertEqual(result['latitude'], '35.0')
        self.assertEqual(result['longitude'], '139.0')

    def test_coordinates_are_valid_pairs(self):
        for fields in [{'latitude': '35'}, {'latitude': 'nan', 'longitude': '139'},
                       {'latitude': '35', 'longitude': '181'}, {'endLatitude': '35'}]:
            with self.assertRaises(ValueError):
                validate_content({'items': [{'id': 'place', 'kind': 'place', 'title': 'Place', **fields}]})
        result = validate_content({'items': [{'id': 'place', 'kind': 'place', 'title': 'Place', 'latitude': '0', 'longitude': '0'}]})
        self.assertEqual(result['items'][0]['latitude'], '0')
