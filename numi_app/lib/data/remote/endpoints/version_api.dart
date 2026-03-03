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

  /// Returns the latest release's build number, page URL, and APK asset
  /// download URL (GitHub API URL — requires Bearer auth + octet-stream).
  /// Returns null if unavailable / token missing / parse error.
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
      final assetApiUrl = (assets != null && assets.isNotEmpty)
          ? (assets[0]['url'] as String?) ?? ''
          : '';
      return (buildNumber: buildNumber, htmlUrl: htmlUrl, assetApiUrl: assetApiUrl);
    } catch (_) {
      return null;
    }
  }
}
