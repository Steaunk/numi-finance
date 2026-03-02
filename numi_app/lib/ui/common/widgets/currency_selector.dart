import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/constants.dart';
import '../../../providers/providers.dart';

class CurrencySelector extends ConsumerWidget {
  const CurrencySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    return PopupMenuButton<String>(
      initialValue: currency,
      onSelected: (value) {
        ref.read(displayCurrencyProvider.notifier).state = value;
        ref.read(sharedPrefsProvider).setString('display_currency', value);
      },
      itemBuilder: (context) => AppConstants.currencies
          .map((c) => PopupMenuItem(value: c, child: Text(c)))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currency, style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}
