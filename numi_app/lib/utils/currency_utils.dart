import 'package:intl/intl.dart';
import '../config/constants.dart';

class CurrencyUtils {
  static final _formatters = <String, NumberFormat>{};

  static NumberFormat _getFormatter(String currency) {
    return _formatters.putIfAbsent(currency, () {
      switch (currency.toUpperCase()) {
        case 'USD':
          return NumberFormat.currency(symbol: '\$', decimalDigits: 2);
        case 'CNY':
          return NumberFormat.currency(symbol: '\u00a5', decimalDigits: 2);
        case 'HKD':
          return NumberFormat.currency(symbol: 'HK\$', decimalDigits: 2);
        case 'SGD':
          return NumberFormat.currency(symbol: 'S\$', decimalDigits: 2);
        case 'JPY':
          return NumberFormat.currency(symbol: '\u00a5', decimalDigits: 0);
        default:
          return NumberFormat.currency(symbol: currency, decimalDigits: 2);
      }
    });
  }

  static String format(double amount, String currency) {
    return _getFormatter(currency).format(amount);
  }

  /// Convert amount from one currency to another using USD-based rates
  static double convert(
    double amount,
    String fromCurrency,
    String toCurrency,
    Map<String, double> rates,
  ) {
    if (fromCurrency == toCurrency) return amount;
    // Convert to USD first
    double amountUsd;
    if (fromCurrency.toUpperCase() == 'USD') {
      amountUsd = amount;
    } else {
      final rate = rates[fromCurrency.toLowerCase()] ?? 1.0;
      amountUsd = rate > 0 ? amount / rate : 0;
    }
    // Convert from USD to target
    if (toCurrency.toUpperCase() == 'USD') return amountUsd;
    final targetRate = rates[toCurrency.toLowerCase()] ?? 1.0;
    return amountUsd * targetRate;
  }

  /// Compute all pre-stored amounts (USD, CNY, HKD, SGD)
  static Map<String, double> computeAmounts(
    double amount,
    String currency,
    Map<String, double> rates,
  ) {
    double amountUsd;
    if (currency.toUpperCase() == 'USD') {
      amountUsd = amount;
    } else {
      final rate = rates[currency.toLowerCase()];
      amountUsd = (rate != null && rate > 0) ? amount / rate : 0;
    }
    return {
      'amount_usd': double.parse(amountUsd.toStringAsFixed(2)),
      'amount_cny': double.parse(
          (amountUsd * (rates['cny'] ?? AppConstants.fallbackRates['cny']!))
              .toStringAsFixed(2)),
      'amount_hkd': double.parse(
          (amountUsd * (rates['hkd'] ?? AppConstants.fallbackRates['hkd']!))
              .toStringAsFixed(2)),
      'amount_sgd': double.parse(
          (amountUsd * (rates['sgd'] ?? AppConstants.fallbackRates['sgd']!))
              .toStringAsFixed(2)),
    };
  }

  /// Get the pre-computed amount for a display currency
  static double getDisplayAmount({
    required String displayCurrency,
    required double amountUsd,
    required double amountCny,
    required double amountHkd,
    required double amountSgd,
    double? originalAmount,
    String? originalCurrency,
  }) {
    // If display currency matches original, use original amount
    if (originalCurrency != null &&
        originalCurrency.toUpperCase() == displayCurrency.toUpperCase()) {
      return originalAmount ?? amountUsd;
    }
    switch (displayCurrency.toUpperCase()) {
      case 'USD':
        return amountUsd;
      case 'CNY':
        return amountCny;
      case 'HKD':
        return amountHkd;
      case 'SGD':
        return amountSgd;
      default:
        return amountUsd;
    }
  }
}
