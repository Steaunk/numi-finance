class PortfolioHolding {
  final String code;
  final String stockName;
  final double qty;
  final double nominalPrice;
  final double marketValue;
  final double usdMarketVal;
  final String currency;
  final String positionMarket;
  final String sector;
  final String industry;
  final String country;
  final String longName;

  const PortfolioHolding({
    required this.code,
    required this.stockName,
    this.qty = 0,
    this.nominalPrice = 0,
    this.marketValue = 0,
    this.usdMarketVal = 0,
    this.currency = '',
    this.positionMarket = '',
    this.sector = '',
    this.industry = '',
    this.country = '',
    this.longName = '',
  });

  factory PortfolioHolding.fromJson(Map<String, dynamic> json) {
    return PortfolioHolding(
      code: json['code'] as String? ?? '',
      stockName: json['stock_name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      nominalPrice: (json['nominal_price'] as num?)?.toDouble() ?? 0,
      marketValue: (json['market_value'] as num?)?.toDouble() ?? 0,
      usdMarketVal: (json['usd_market_val'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? '',
      positionMarket: json['position_market'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      country: json['country'] as String? ?? '',
      longName: json['long_name'] as String? ?? '',
    );
  }

  String get displayName => longName.isNotEmpty ? longName : stockName;
}

class PortfolioSummary {
  final List<PortfolioHolding> holdings;
  final double totalUsd;
  final String timestamp;

  const PortfolioSummary({
    required this.holdings,
    required this.totalUsd,
    required this.timestamp,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    final holdingsList = (json['holdings'] as List? ?? [])
        .map((h) => PortfolioHolding.fromJson(h as Map<String, dynamic>))
        .toList();
    return PortfolioSummary(
      holdings: holdingsList,
      totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class StockHistoryPoint {
  final DateTime timestamp;
  final double usdMarketVal;
  final double marketValue;
  final double qty;

  const StockHistoryPoint({
    required this.timestamp,
    required this.usdMarketVal,
    required this.marketValue,
    required this.qty,
  });

  factory StockHistoryPoint.fromJson(Map<String, dynamic> json) {
    return StockHistoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      usdMarketVal: (json['usd_market_val'] as num?)?.toDouble() ?? 0,
      marketValue: (json['market_value'] as num?)?.toDouble() ?? 0,
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PortfolioHistorySnapshot {
  final DateTime timestamp;
  final double totalUsd;

  const PortfolioHistorySnapshot({
    required this.timestamp,
    required this.totalUsd,
  });
}
