import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../utils/account_icon_utils.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/sync_status_indicator.dart';
import 'add_account_screen.dart';
import 'update_account_screen.dart';

class AssetOverviewScreen extends ConsumerWidget {
  const AssetOverviewScreen({super.key});

  static String _formatRunway(double months) {
    if (months <= 0) return '0 months';
    final years = (months / 12).floor();
    final rem = (months % 12).round();
    if (years == 0) return '$rem months';
    if (rem == 0) return '$years years';
    return '$years years $rem months';
  }

  Widget _buildFireCard(
      BuildContext context, WidgetRef ref, String currency) {
    final fireAsync = ref.watch(fireProgressProvider);
    return fireAsync.when(
      data: (fire) {
        if (fire.annualSpending <= 0) return const SizedBox.shrink();
        final pct = (fire.progress * 100).clamp(0, 9999);
        final progressClamped = fire.progress.clamp(0.0, 1.0);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('FIRE Progress',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressClamped,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spending: ${CurrencyUtils.format(fire.annualSpending, currency)}/yr',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Target: ${CurrencyUtils.format(fire.fireNumber, currency)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Runway: ${_formatRunway(fire.runwayMonths)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAccountAvatar(BuildContext context, dynamic account) {
    final bgColor = account.includeInTotal
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final iconColor = account.includeInTotal
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final iconWidget = AccountIconUtils.getIconWidget(account.name, iconColor);
    if (iconWidget != null) {
      return CircleAvatar(
        backgroundColor: bgColor,
        child: iconWidget,
      );
    }
    return CircleAvatar(
      backgroundColor: bgColor,
      child: Text(
        account.currency,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);
    final netWorthAsync = ref.watch(netWorthProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        actions: const [CurrencySelector(), SyncStatusIndicator()],
      ),
      body: Column(
        children: [
          // Net worth card
          netWorthAsync.when(
            data: (netWorth) => Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Net Worth',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyUtils.format(netWorth, displayCurrency),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => const SizedBox.shrink(),
          ),
          // FIRE progress card
          _buildFireCard(context, ref, displayCurrency),
          // Account list
          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.account_balance,
                    message: 'No accounts yet',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(syncStateProvider.notifier).syncNow(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              context.go('/assets/${account.id}'),
                          onLongPress: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (ctx) =>
                                UpdateAccountScreen(account: account),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _buildAccountAvatar(context, account),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(account.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      Text(
                                        CurrencyUtils.format(
                                            account.balance,
                                            account.currency),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyUtils.format(
                                          account.convertedBalance,
                                          displayCurrency),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    if (!account.includeInTotal)
                                      Text(
                                        'Excluded',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => const AddAccountScreen(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
