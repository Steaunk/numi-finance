import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../config/constants.dart';
import '../../../providers/providers.dart';
import '../../../data/remote/api_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;
  bool _testing = false;
  String? _testResult;
  bool _obscurePass = true;

  // Update check state
  bool _updateChecking = false;
  String? _updateStatus; // null = not checked, 'none' = up to date, 'available' = update ready
  String? _updateAssetUrl;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(serverUrlProvider));
    _userController = TextEditingController(text: ref.read(nginxUsernameProvider));
    _passController = TextEditingController(text: ref.read(nginxPasswordProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingCountProvider);
    final isOnline = ref.watch(connectivityProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server URL
          Text('Server Connection',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://your-server.com',
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveUrl,
              ),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _saveUrl(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  onSubmitted: (_) => _saveCredentials(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _passController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  onSubmitted: (_) => _saveCredentials(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save credentials',
                onPressed: _saveCredentials,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_find, size: 18),
                label: const Text('Test Connection'),
              ),
              const SizedBox(width: 12),
              if (_testResult != null)
                Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult == 'Connected!'
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Display Currency
          Text('Display Currency',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: AppConstants.currencies
                .map((c) => ButtonSegment(value: c, label: Text(c)))
                .toList(),
            selected: {displayCurrency},
            onSelectionChanged: (selected) {
              final currency = selected.first;
              ref.read(displayCurrencyProvider.notifier).state = currency;
              ref.read(sharedPrefsProvider).setString(
                  'display_currency', currency);
            },
          ),
          const SizedBox(height: 24),
          // Sync
          Text('Sync', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: isOnline ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(isOnline ? 'Online' : 'Offline'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  pendingCount.when(
                    data: (count) =>
                        Text('Pending operations: $count'),
                    loading: () => const Text('Pending operations: ...'),
                    error: (_, __) =>
                        const Text('Pending operations: ?'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: syncState.isLoading
                        ? null
                        : () => ref
                            .read(syncStateProvider.notifier)
                            .syncNow(),
                    icon: syncState.isLoading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label: Text(
                        syncState.isLoading ? 'Syncing...' : 'Sync Now'),
                  ),
                  if (syncState.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sync error: ${syncState.error}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // App Updates
          Text('App Updates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _updateChecking ? null : _checkForUpdates,
                        icon: _updateChecking
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.system_update, size: 18),
                        label: const Text('Check for Updates'),
                      ),
                      const SizedBox(width: 12),
                      if (_updateStatus == 'none')
                        const Row(children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          SizedBox(width: 4),
                          Text('Up to date'),
                        ]),
                    ],
                  ),
                  if (_updateStatus == 'available') ...[
                    const SizedBox(height: 12),
                    const Text('A new version of Numi is available!'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _downloadAndInstall(_updateAssetUrl!),
                      icon: const Icon(Icons.download),
                      label: const Text('Download & Install'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveUrl() {
    final url = _urlController.text.trim();
    ref.read(serverUrlProvider.notifier).state = url;
    ref.read(sharedPrefsProvider).setString('server_url', url);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Server URL saved')));
  }

  void _saveCredentials() {
    final user = _userController.text.trim();
    final pass = _passController.text;
    ref.read(nginxUsernameProvider.notifier).state = user;
    ref.read(nginxPasswordProvider.notifier).state = pass;
    ref.read(sharedPrefsProvider).setString('nginx_username', user);
    ref.read(sharedPrefsProvider).setString('nginx_password', pass);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Credentials saved')));
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _testResult = 'Enter a URL first');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final user = _userController.text.trim();
      final pass = _passController.text;
      final client = ApiClient(
        url,
        username: user.isEmpty ? null : user,
        password: pass.isEmpty ? null : pass,
      );
      final ok = await client.testConnection();
      setState(() => _testResult = ok ? 'Connected!' : 'Failed');
    } catch (e) {
      setState(() => _testResult = 'Error: $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _updateChecking = true;
      _updateStatus = null;
      _updateAssetUrl = null;
    });
    ref.invalidate(updateCheckProvider);
    try {
      final result = await ref.read(updateCheckProvider.future);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _updateStatus = 'available';
          _updateAssetUrl = result.assetApiUrl;
        });
      } else {
        setState(() => _updateStatus = 'none');
      }
    } catch (_) {
      if (mounted) setState(() => _updateStatus = 'none');
    } finally {
      if (mounted) setState(() => _updateChecking = false);
    }
  }

  Future<void> _downloadAndInstall(String assetApiUrl) async {
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

      // Step 1: Follow GitHub's redirect to CDN URL (public repo, no auth needed).
      final redirectResp = await Dio(BaseOptions(
        headers: {'Accept': 'application/octet-stream'},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      )).get(assetApiUrl);

      final downloadUrl = redirectResp.headers.value('location');
      if (downloadUrl == null) {
        throw Exception('GitHub did not return a download URL');
      }

      // Step 2: Download from CDN (pre-signed URL, no auth required)
      await Dio().download(
        downloadUrl,
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
}
