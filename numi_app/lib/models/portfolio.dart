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
  final double pnl;
  final double unrealizedPnl;
  final double realizedPnl;

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
    this.pnl = 0,
    this.unrealizedPnl = 0,
    this.realizedPnl = 0,
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
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      unrealizedPnl: (json['unrealized_pnl'] as num?)?.toDouble() ?? 0,
      realizedPnl: (json['realized_pnl'] as num?)?.toDouble() ?? 0,
    );
  }

  String get displayName => longName.isNotEmpty ? longName : stockName;
}

class PortfolioSummary {
  final List<PortfolioHolding> holdings;
  final double totalUsd;
  final String timestamp;

  double get totalPnl => holdings.fold(0.0, (sum, h) => sum + h.pnl);

  const PortfolioSummary({
    required this.holdings,
    required this.totalUsd,
    required this.timestamp,
  });

  factory PortfolioSummary.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? accountJson,
  }) {
    final holdingsList = (json['holdings'] as List? ?? [])
        .map((h) => PortfolioHolding.fromJson(h as Map<String, dynamic>))
        .toList();

    double totalUsd = (json['total_usd'] as num?)?.toDouble() ?? 0;

    // Add fund, bond, cash from account data as synthetic holdings
    if (accountJson != null) {
      final fund = (accountJson['fund_assets'] as num?)?.toDouble() ?? 0;
      final bond = (accountJson['bond_assets'] as num?)?.toDouble() ?? 0;
      final cash = (accountJson['cash'] as num?)?.toDouble() ?? 0;

      if (fund > 0) {
        holdingsList.add(PortfolioHolding(
          code: 'FUND',
          stockName: 'Fund',
          longName: 'Fund Assets',
          qty: fund,
          nominalPrice: 1,
          marketValue: fund,
          usdMarketVal: fund,
          currency: 'USD',
          sector: 'Fund',
        ));
        totalUsd += fund;
      }
      if (bond > 0) {
        holdingsList.add(PortfolioHolding(
          code: 'BOND',
          stockName: 'Bond',
          longName: 'Bond Assets',
          qty: bond,
          nominalPrice: 1,
          marketValue: bond,
          usdMarketVal: bond,
          currency: 'USD',
          sector: 'Bond',
        ));
        totalUsd += bond;
      }
      if (cash > 0) {
        holdingsList.add(PortfolioHolding(
          code: 'CASH',
          stockName: 'Cash',
          longName: 'Cash',
          qty: cash,
          nominalPrice: 1,
          marketValue: cash,
          usdMarketVal: cash,
          currency: 'USD',
          sector: 'Cash',
        ));
        totalUsd += cash;
      }
    }

    // Sort by USD value descending
    holdingsList.sort((a, b) => b.usdMarketVal.compareTo(a.usdMarketVal));

    return PortfolioSummary(
      holdings: holdingsList,
      totalUsd: totalUsd,
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
  final double pnl;

  const PortfolioHistorySnapshot({
    required this.timestamp,
    required this.totalUsd,
    this.pnl = 0,
  });
}
