class ExchangeRate {
  final int id;
  final DateTime rateDate;
  final double cny;
  final double hkd;
  final double sgd;
  final double jpy;

  const ExchangeRate({
    required this.id,
    required this.rateDate,
    required this.cny,
    required this.hkd,
    required this.sgd,
    required this.jpy,
  });
}
