import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const NumiApp(),
    ),
  );
}

class NumiApp extends ConsumerStatefulWidget {
  const NumiApp({super.key});

  @override
  ConsumerState<NumiApp> createState() => _NumiAppState();
}

class _NumiAppState extends ConsumerState<NumiApp> {
  @override
  void initState() {
    super.initState();
    // Auto-sync on startup if server configured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSync();
    });
  }

  Future<void> _initSync() async {
    final serverUrl = ref.read(serverUrlProvider);
    if (serverUrl.isNotEmpty) {
      // Fetch exchange rates and sync
      await ref.read(rateRepositoryProvider).fetchAndCacheRates();
      ref.read(syncStateProvider.notifier).syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for connectivity changes to auto-sync
    ref.listen(connectivityProvider, (prev, next) {
      final wasOffline = prev?.value == false;
      final isNowOnline = next.value == true;
      if (wasOffline && isNowOnline) {
        ref.read(syncStateProvider.notifier).syncNow();
      }
    });

    return MaterialApp.router(
      title: 'Numi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
