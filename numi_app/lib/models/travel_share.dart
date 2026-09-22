import 'trip_plan.dart';

class TravelShareDraft {
  final Map<String, dynamic> data;
  TravelShareDraft(this.data);
  String get warning => data['warning'] as String? ?? '';
  String get source => data['source'] as String? ?? '';
  String value(String key) => data[key] as String? ?? '';
  bool get isStay => value('category') == 'Accommodation';
  String get suggestedKind =>
      ['booking', 'activity', 'place'].contains(value('kind'))
          ? value('kind')
          : isStay && value('date').isNotEmpty && value('endDate').isNotEmpty
              ? 'booking'
              : 'place';

  factory TravelShareDraft.offline(String text, String url) =>
      TravelShareDraft({
        'notes': text,
        'source': linkPlatform(url),
        'warning':
            'Could not analyze the link. You can still review and save it manually.',
        'links': [
          if (url.isNotEmpty)
            {'url': url, 'label': linkPlatform(url), 'purpose': 'Website'}
        ],
      });

  PlanItem item(String kind) {
    final category = value('category');
    return PlanItem.create(kind).copy({
      for (final key in [
        'documentId',
        'documentName',
        'confirmation',
        'title',
        'address',
        'notes',
        'endAddress',
        'latitude',
        'longitude',
        'endLatitude',
        'endLongitude'
      ])
        key: value(key),
      if (kind == 'booking') ...{
        'category':
            bookingCategories.contains(category) ? category : 'Reservation',
        for (final key in [
          'date',
          'endDate',
          'time',
          'endTime',
          'timezone',
          'endTimezone'
        ])
          key: value(key),
      } else
        'category': placeCategories.contains(category) ? category : 'Other',
      if (kind == 'activity')
        for (final key in ['date', 'time', 'timezone']) key: value(key),
      'status': 'planned',
    },
        links: (data['links'] as List? ?? [])
            .map((l) => PlanLink.fromJson(Map<String, dynamic>.from(l)))
            .toList());
  }
}
