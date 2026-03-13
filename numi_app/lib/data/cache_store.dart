import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent JSON cache with TTL.
///
/// Entry format: `{"ts": <cache_epoch_ms>, "dataTs": <data_timestamp>, "data": <json>}`
/// - `ts`: when the cache entry was written (for TTL)
/// - `dataTs`: backend data timestamp (for freshness comparison)
class CacheStore {
  final SharedPreferences _prefs;
  static const _maxAge = Duration(days: 7);
  static const _prefix = 'cache:';

  CacheStore(this._prefs);

  /// Read a cached value. Returns `null` if missing or older than [_maxAge].
  T? get<T>(String key, T Function(dynamic json) deserialize) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final ts = wrapper['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _maxAge.inMilliseconds) {
        return null;
      }
      return deserialize(wrapper['data']);
    } catch (_) {
      return null;
    }
  }

  /// How old the cache entry is, or `null` if not cached / expired.
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

  /// The stored data timestamp (from backend), or `null` if not cached.
  String? dataTimestamp(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      return wrapper['dataTs'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Write a value to cache.
  /// [dataTimestamp] is the backend's data timestamp (e.g. API response timestamp
  /// or the last entry's timestamp). Returns `true` if data is newer than cached.
  Future<bool> put(String key, dynamic data, {String? dataTimestamp}) async {
    final oldTs = this.dataTimestamp(key);
    final isNewer = oldTs == null || dataTimestamp == null || dataTimestamp != oldTs;

    final wrapper = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'dataTs': dataTimestamp,
      'data': data,
    });
    await _prefs.setString('$_prefix$key', wrapper);
    return isNewer;
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
