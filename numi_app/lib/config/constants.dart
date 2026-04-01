class AppConstants {
  static const List<String> currencies = ['USD', 'CNY', 'HKD', 'SGD'];
  static const String defaultCurrency = 'SGD';

  /// Extended currency list for travel expenses.
  static const List<String> travelCurrencies = [
    'USD',
    'CNY',
    'HKD',
    'SGD',
    'JPY',
    'EUR',
    'GBP',
    'AUD',
    'KRW',
    'TWD',
    'THB',
    'MYR',
    'IDR',
    'VND',
    'PHP',
    'INR',
    'CAD',
    'CHF',
    'NZD',
    'SEK',
    'NOK',
    'DKK',
    'AED',
  ];

  static const List<String> travelCategories = [
    'Transportation',
    'Accommodation',
    'Sightseeing',
    'Food & Drinks',
    'Shopping',
    'Other',
  ];

  static const double defaultFireRate = 0.04;

  static const Map<String, double> fallbackRates = {
    'cny': 7.25,
    'hkd': 7.82,
    'sgd': 1.34,
    'jpy': 150.0,
    'eur': 0.92,
    'gbp': 0.79,
    'aud': 1.55,
    'krw': 1380.0,
    'twd': 32.5,
    'thb': 35.8,
    'myr': 4.73,
    'idr': 16200.0,
    'vnd': 25400.0,
    'php': 56.5,
    'inr': 85.0,
    'cad': 1.37,
    'chf': 0.88,
    'nzd': 1.68,
    'sek': 10.8,
    'nok': 10.9,
    'dkk': 6.88,
    'aed': 3.67,
  };
}
