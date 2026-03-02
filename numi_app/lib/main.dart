import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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
    final update = await ref.read(updateCheckProvider.future);
    if (update != null && mounted) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update Available'),
          content: const Text('A new version of Numi is ready.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _downloadAndInstall(update.assetApiUrl);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadAndInstall(String assetApiUrl) async {
    final token = ref.read(githubTokenProvider);
    final progressNotifier = ValueNotifier<double>(0);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Downloading...'),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value > 0 ? value : null),
              if (value > 0) ...[
                const SizedBox(height: 8),
                Text('${(value * 100).toInt()}%'),
              ],
            ],
          ),
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/numi_update.apk';

      await Dio(BaseOptions(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/octet-stream',
        },
        followRedirects: true,
        maxRedirects: 5,
      )).download(
        assetApiUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) progressNotifier.value = received / total;
        },
      );

      progressNotifier.dispose();
      if (mounted) {
        Navigator.pop(context);
        await OpenFilex.open(savePath);
      }
    } catch (e) {
      progressNotifier.dispose();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
