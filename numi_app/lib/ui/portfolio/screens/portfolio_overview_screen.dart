import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/portfolio.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/empty_state.dart';

class PortfolioOverviewScreen extends ConsumerWidget {
  const PortfolioOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocks'),
      ),
      body: summaryAsync.when(
        data: (summary) {
          if (summary == null || summary.holdings.isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart,
              message: 'No portfolio data',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(portfolioRepositoryProvider).invalidateCache();
              ref.invalidate(portfolioSummaryProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PortfolioSummaryCard(summary: summary),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: summary.holdings.length,
                    itemBuilder: (context, index) {
                      final holding = summary.holdings[index];
                      return _HoldingListTile(
                        holding: holding,
                        totalUsd: summary.totalUsd,
                        onTap: () => context.go(
                          '/portfolio/stock/${Uri.encodeComponent(holding.stockName)}',
                          extra: holding,
                        ),
                      );
                    },
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'Unable to load portfolio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(portfolioRepositoryProvider).invalidateCache();
                    ref.invalidate(portfolioSummaryProvider);
                  },
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

class _PortfolioSummaryCard extends StatelessWidget {
  final PortfolioSummary summary;
  const _PortfolioSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Portfolio Value',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.format(summary.totalUsd, 'USD'),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.holdings.length} holdings',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingListTile extends StatelessWidget {
  final PortfolioHolding holding;
  final double totalUsd;
  final VoidCallback onTap;

  const _HoldingListTile({
    required this.holding,
    required this.totalUsd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalUsd > 0 ? (holding.usdMarketVal / totalUsd * 100) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  holding.code.length >= 2
                      ? holding.code.substring(0, 2)
                      : holding.code,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${holding.code}  ${holding.qty.toStringAsFixed(holding.qty == holding.qty.roundToDouble() ? 0 : 2)} shares',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.format(holding.usdMarketVal, 'USD'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
