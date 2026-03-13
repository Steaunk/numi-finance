import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent JSON cache with TTL.
///
/// Every entry is stored as `{"ts": <epoch_ms>, "hash": <int>, "data": <json>}`
/// in SharedPreferences under a `cache:` prefix.
///
/// The hash allows detecting whether new data is actually different from what's
/// cached, so background refreshes only notify the UI when data changed.
class CacheStore {
  final SharedPreferences _prefs;
  static const _maxAge = Duration(days: 7);
  static const _prefix = 'cache:';

  CacheStore(this._prefs);

  /// Read a cached value.  Returns `null` if missing or older than [_maxAge].
  T? get<T>(String key, T Function(dynamic json) deserialize) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final ts = wrapper['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _maxAge.inMilliseconds) {
        return null; // expired
      }
      return deserialize(wrapper['data']);
    } catch (_) {
      return null;
    }
  }

  /// How old the cached entry is, or `null` if not cached / expired.
  Duration? age(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final ts = wrapper['ts'] as int;
      final a = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - ts);
      return a > _maxAge ? null : a;
    } catch (_) {
      return null;
    }
  }

  /// Write a value to cache. Returns `true` if the data actually changed
  /// (different from what was previously cached).
  Future<bool> put(String key, dynamic data) async {
    final encoded = jsonEncode(data);
    final newHash = encoded.hashCode;

    // Check if data changed
    final existing = _prefs.getString('$_prefix$key');
    if (existing != null) {
      try {
        final wrapper = jsonDecode(existing) as Map<String, dynamic>;
        final oldHash = wrapper['hash'] as int?;
        if (oldHash == newHash) {
          // Data unchanged — just bump the timestamp so it stays fresh
          wrapper['ts'] = DateTime.now().millisecondsSinceEpoch;
          await _prefs.setString('$_prefix$key', jsonEncode(wrapper));
          return false;
        }
      } catch (_) {
        // corrupt entry, overwrite
      }
    }

    final wrapper = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'hash': newHash,
      'data': data,
    });
    await _prefs.setString('$_prefix$key', wrapper);
    return true;
  }

  /// Remove a single entry.
  Future<void> remove(String key) => _prefs.remove('$_prefix$key');

  /// Remove all entries matching a prefix.
  Future<void> removeByPrefix(String prefix) async {
    final fullPrefix = '$_prefix$prefix';
    final keys = _prefs.getKeys().where((k) => k.startsWith(fullPrefix));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  /// Remove all cache entries.
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
