import 'package:flutter/services.dart';

/// The Android queue retains unhandled shares across cold starts. Only remove
/// one after its review screen is dismissed, and serialize warm-start shares.
class TravelShareReceiver {
  final MethodChannel channel;
  final Future<void> Function(String text) open;
  final Future<void> Function(Map<String, dynamic> document)? openDocument;
  bool _running = false;
  bool _disposed = false;
  TravelShareReceiver(this.open,
      {this.openDocument,
      this.channel = const MethodChannel('numi/travel_share')});

  Future<void> start() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'received') await drain();
    });
    await drain();
  }

  Future<void> drain() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (!_disposed) {
        final next = await channel.invokeMapMethod<String, dynamic>('peek');
        if (next == null || _disposed) return;
        if (next['type'] == 'pdf') {
          if (openDocument == null) return;
          await openDocument!(next);
        } else {
          await open(next['text'] as String);
        }
        await channel.invokeMethod<void>('acknowledge', next['id']);
      }
    } on PlatformException {
      // Keep the native queue for the next launch.
    } on MissingPluginException {
      // The share receiver is Android-only.
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    channel.setMethodCallHandler(null);
  }
}
