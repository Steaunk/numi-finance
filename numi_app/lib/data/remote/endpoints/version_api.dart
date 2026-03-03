import 'dart:io';

import 'package:dio/dio.dart';

/// Checks GitHub Releases for the latest Numi build.
/// Tag format: "v20260303.1" — date (YYYYMMDD) + daily sequence.
/// Build number = YYYYMMDD * 100 + seq (monotonically increasing).
class VersionApi {
  final Dio _dio;

  VersionApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.github.com',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          ),
        );

  /// Returns the latest release's build number, page URL, and platform-specific
  /// asset download URL (GitHub API URL — requires Accept: octet-stream).
  /// Returns null if unavailable / no matching asset / parse error.
  Future<({int buildNumber, String htmlUrl, String assetApiUrl})?> getLatestRelease() async {
    try {
      final resp = await _dio.get(
          '/repos/Steaunk/numi-finance/releases/latest');
      final tag = (resp.data['tag_name'] as String?) ?? '';

      // tag = "v20260303.1"
      if (!tag.startsWith('v')) return null;
      final stripped = tag.substring(1); // "20260303.1"
      final dotIndex = stripped.indexOf('.');
      if (dotIndex < 0) return null;
      final dateNum = int.tryParse(stripped.substring(0, dotIndex));
      final seq = int.tryParse(stripped.substring(dotIndex + 1));
      if (dateNum == null || seq == null) return null;
      final buildNumber = dateNum * 100 + seq;

      final htmlUrl = (resp.data['html_url'] as String?) ?? '';
      final assets = resp.data['assets'] as List?;

      // Find the right asset for this platform
      final ext = Platform.isAndroid ? '.apk' : '.dmg';
      final assetApiUrl = _findAssetUrl(assets, ext);

      return (buildNumber: buildNumber, htmlUrl: htmlUrl, assetApiUrl: assetApiUrl);
    } catch (_) {
      return null;
    }
  }

  String _findAssetUrl(List? assets, String extension) {
    if (assets == null || assets.isEmpty) return '';
    for (final asset in assets) {
      final name = (asset['name'] as String?) ?? '';
      if (name.endsWith(extension)) {
        return (asset['url'] as String?) ?? '';
      }
    }
    // Fallback to first asset
    return (assets[0]['url'] as String?) ?? '';
  }
}
