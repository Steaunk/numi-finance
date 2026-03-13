import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/providers.dart';
import 'utils/account_icon_utils.dart';
import 'ui/common/widgets/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await AccountIconUtils.restoreFromCache(prefs);

  // Read nginx credentials from secure storage
  const secureStorage = FlutterSecureStorage();
  var username = await secureStorage.read(key: 'nginx_username') ?? '';
  var password = await secureStorage.read(key: 'nginx_password') ?? '';

  // Migrate from SharedPreferences if secure storage is empty
  if (username.isEmpty && password.isEmpty) {
    final oldUser = prefs.getString('nginx_username') ?? '';
    final oldPass = prefs.getString('nginx_password') ?? '';
    if (oldUser.isNotEmpty || oldPass.isNotEmpty) {
      await secureStorage.write(key: 'nginx_username', value: oldUser);
      await secureStorage.write(key: 'nginx_password', value: oldPass);
      await prefs.remove('nginx_username');
      await prefs.remove('nginx_password');
      username = oldUser;
      password = oldPass;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        nginxUsernameProvider.overrideWith((_) => username),
        nginxPasswordProvider.overrideWith((_) => password),
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
    });
  }

  Future<void> _initSync() async {
    final serverUrl = ref.read(serverUrlProvider);
    if (serverUrl.isNotEmpty) {
      await ref.read(rateRepositoryProvider).fetchAndCacheRates();
      ref.read(syncStateProvider.notifier).syncNow();
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
      builder: (context, child) => LockScreen(child: child!),
    );
  }
}
