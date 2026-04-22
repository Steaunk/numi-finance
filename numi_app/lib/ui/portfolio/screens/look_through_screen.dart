import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/currency_selector.dart';

class LookThroughScreen extends ConsumerStatefulWidget {
  const LookThroughScreen({super.key});

  @override
  ConsumerState<LookThroughScreen> createState() => _LookThroughScreenState();
}

class _LookThroughScreenState extends ConsumerState<LookThroughScreen> {
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(lookThroughProvider(_limit));
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final ratesAsync = ref.watch(cachedRatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Look-through'),
        actions: const [CurrencySelector()],
      ),
      body: dataAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No data'));
          }
          final holdings = (data['holdings'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final totalUsd = (data['total_usd'] as num?)?.toDouble() ?? 0;
          final unresolvedUsd =
              (data['unresolved_etf_usd'] as num?)?.toDouble() ?? 0;
          final totalCount = (data['total_count'] as num?)?.toInt() ?? 0;

          if (holdings.isEmpty) {
            return const Center(child: Text('No holdings'));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(lookThroughProvider(_limit)),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeaderCard(
                    totalUsd: totalUsd,
                    totalCount: totalCount,
                    unresolvedUsd: unresolvedUsd,
                    limit: _limit,
                    onLimitChanged: (v) => setState(() => _limit = v),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: holdings.length,
                    itemBuilder: (context, index) => _LookThroughTile(
                      rank: index + 1,
                      holding: holdings[index],
                      totalUsd: totalUsd,
                      displayCurrency: displayCurrency,
                      rates: ratesAsync.valueOrNull ?? const {},
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text('Failed to load look-through',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('$e',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(lookThroughProvider(_limit)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  final double totalUsd;
  final int totalCount;
  final double unresolvedUsd;
  final int limit;
  final ValueChanged<int> onLimitChanged;

  const _HeaderCard({
    required this.totalUsd,
    required this.totalCount,
    required this.unresolvedUsd,
    required this.limit,
    required this.onLimitChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final ratesAsync = ref.watch(cachedRatesProvider);
    final displayTotal = ratesAsync.when(
      data: (rates) =>
          CurrencyUtils.convert(totalUsd, 'USD', displayCurrency, rates),
      loading: () => totalUsd,
      error: (_, __) => totalUsd,
    );
    final currencyLabel = ratesAsync.hasValue ? displayCurrency : 'USD';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total resolved exposure',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.format(displayTotal, currencyLabel),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalCount underlying names'
              '${unresolvedUsd > 0 ? ' · unresolved ${CurrencyUtils.format(unresolvedUsd, "USD")}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 20, label: Text('Top 20')),
                ButtonSegment(value: 50, label: Text('Top 50')),
                ButtonSegment(value: 100, label: Text('Top 100')),
                ButtonSegment(value: 200, label: Text('All')),
              ],
              selected: {limit},
              onSelectionChanged: (v) => onLimitChanged(v.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookThroughTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> holding;
  final double totalUsd;
  final String displayCurrency;
  final Map<String, double> rates;

  const _LookThroughTile({
    required this.rank,
    required this.holding,
    required this.totalUsd,
    required this.displayCurrency,
    required this.rates,
  });

  @override
  Widget build(BuildContext context) {
    final code = holding['code'] as String? ?? '';
    final name = holding['name'] as String? ?? code;
    final totalVal = (holding['total_usd'] as num?)?.toDouble() ?? 0;
    final directVal = (holding['direct_usd'] as num?)?.toDouble() ?? 0;
    final viaEtfVal = (holding['via_etf_usd'] as num?)?.toDouble() ?? 0;
    final viaEtfs = (holding['via_etfs'] as List? ?? []).cast<String>();

    final pct = totalUsd > 0 ? (totalVal / totalUsd * 100) : 0.0;
    final displayVal =
        CurrencyUtils.convert(totalVal, 'USD', displayCurrency, rates);
    final currencyLabel = rates.isNotEmpty ? displayCurrency : 'USD';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#$rank',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : code,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  if (viaEtfs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (directVal > 0)
                          _BreakdownChip(
                            label:
                                'Direct ${CurrencyUtils.format(CurrencyUtils.convert(directVal, "USD", displayCurrency, rates), currencyLabel)}',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        _BreakdownChip(
                          label:
                              'via ${viaEtfs.join(", ")} ${CurrencyUtils.format(CurrencyUtils.convert(viaEtfVal, "USD", displayCurrency, rates), currencyLabel)}',
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyUtils.format(displayVal, currencyLabel),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${pct.toStringAsFixed(pct < 1 ? 2 : 1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BreakdownChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
