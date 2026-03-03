import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/sync_status_indicator.dart';
import 'add_account_screen.dart';
import 'update_account_screen.dart';

class AssetOverviewScreen extends ConsumerWidget {
  const AssetOverviewScreen({super.key});

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
                                CircleAvatar(
                                  backgroundColor: account.includeInTotal
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  child: Text(
                                    account.currency,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
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
