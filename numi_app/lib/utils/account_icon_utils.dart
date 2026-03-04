class AccountIconUtils {
  static const _mappings = [
    (key: 'moomoo', keywords: ['moomoo']),
    (key: 'ibkr', keywords: ['ibkr', 'interactive brokers']),
    (key: 'dbs', keywords: ['\u661f\u5c55', 'dbs']),
    (key: 'uob', keywords: ['united overseas', 'uob']),
    (key: 'icbc', keywords: ['icbc', '\u5de5\u5546\u94f6\u884c']),
    (key: 'boc', keywords: ['\u4e2d\u56fd\u94f6\u884c', 'bank of china', 'boc']),
    (key: 'cmb', keywords: ['\u62db\u5546\u94f6\u884c', '\u62db\u5546', 'cmb']),
    (key: 'okx', keywords: ['okx', 'okex']),
    (key: 'bond', keywords: ['sgs', 'bond', 'treasury']),
    (key: 'crypto', keywords: ['crypto', 'bitcoin', 'btc', 'eth']),
    (key: 'cash', keywords: ['cash']),
  ];

  /// Returns the asset path for the account's brand icon, or null if unknown.
  static String? logoAssetPath(String accountName) {
    final lower = accountName.toLowerCase();
    for (final m in _mappings) {
      if (m.keywords.any((k) => lower.contains(k))) {
        return 'assets/icons/${m.key}.svg';
      }
    }
    return null;
  }
}
