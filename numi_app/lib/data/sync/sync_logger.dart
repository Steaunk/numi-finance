import 'dart:collection';
import 'dart:developer' as developer;

class SyncLogEntry {
  final DateTime time;
  final String source;
  final String message;

  SyncLogEntry(this.source, this.message) : time = DateTime.now();

  @override
  String toString() {
    final t = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    return '[$t] $source: $message';
  }
}

class SyncLogger {
  static final SyncLogger instance = SyncLogger._();
  SyncLogger._();

  static const _maxEntries = 100;
  final _entries = Queue<SyncLogEntry>();

  List<SyncLogEntry> get entries => _entries.toList();

  void log(String message, {required String name, Object? error, StackTrace? stackTrace}) {
    final entry = SyncLogEntry(name, message);
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    developer.log(message, name: name, error: error, stackTrace: stackTrace);
  }

  void clear() => _entries.clear();
}
