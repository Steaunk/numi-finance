import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingCountProvider);
    final isOnline = ref.watch(connectivityProvider).value ?? false;

    return IconButton(
      onPressed: () => ref.read(syncStateProvider.notifier).syncNow(),
      icon: syncState.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Badge(
              isLabelVisible: (pendingCount.value ?? 0) > 0,
              label: Text('${pendingCount.value ?? 0}'),
              child: Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: isOnline ? null : Theme.of(context).colorScheme.error,
              ),
            ),
      tooltip: syncState.isLoading
          ? 'Syncing...'
          : isOnline
              ? 'Tap to sync'
              : 'Offline',
    );
  }
}
