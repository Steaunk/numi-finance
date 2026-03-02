import 'package:flutter/material.dart';
import '../../../utils/currency_utils.dart';

class AmountDisplay extends StatelessWidget {
  final double amount;
  final String currency;
  final double? originalAmount;
  final String? originalCurrency;
  final TextStyle? style;

  const AmountDisplay({
    super.key,
    required this.amount,
    required this.currency,
    this.originalAmount,
    this.originalCurrency,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final showOriginal = originalCurrency != null &&
        originalCurrency!.toUpperCase() != currency.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CurrencyUtils.format(amount, currency),
          style: style ?? Theme.of(context).textTheme.titleMedium,
        ),
        if (showOriginal && originalAmount != null)
          Text(
            CurrencyUtils.format(originalAmount!, originalCurrency!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
      ],
    );
  }
}
