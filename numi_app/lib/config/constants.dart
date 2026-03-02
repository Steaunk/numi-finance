class AppConstants {
  static const List<String> currencies = ['USD', 'CNY', 'HKD', 'SGD'];
  static const String defaultCurrency = 'SGD';

  static const List<String> travelCategories = [
    'Transportation',
    'Accommodation',
    'Sightseeing',
    'Food & Drinks',
    'Shopping',
    'Other',
  ];

  static const Map<String, double> fallbackRates = {
    'cny': 7.25,
    'hkd': 7.82,
    'sgd': 1.34,
    'jpy': 150.0,
  };
}
