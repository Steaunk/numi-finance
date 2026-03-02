import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSync();
      _checkForUpdate();
    });
  }

  Future<void> _initSync() async {
    final serverUrl = ref.read(serverUrlProvider);
    if (serverUrl.isNotEmpty) {
      await ref.read(rateRepositoryProvider).fetchAndCacheRates();
      ref.read(syncStateProvider.notifier).syncNow();
    }
  }

  Future<void> _checkForUpdate() async {
    final url = await ref.read(updateCheckProvider.future);
    if (url != null && mounted) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update Available'),
          content: const Text('A new version of Numi is ready to download.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
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
