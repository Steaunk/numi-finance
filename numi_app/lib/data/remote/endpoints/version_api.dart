import 'package:dio/dio.dart';

/// Checks GitHub Releases for the latest Numi build.
///
/// Tag formats:
///   New: "v20260303.1" — date (YYYYMMDD) + daily sequence.
///        Build number = YYYYMMDD * 100 + seq.
///   Legacy: "build-N" — plain integer.
class VersionApi {
  final Dio _dio;

  VersionApi(String githubToken)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.github.com',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Authorization': 'Bearer $githubToken',
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

      final buildNumber = _parseBuildNumber(tag);
      if (buildNumber == null) return null;

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

  /// Parse tag into a monotonically increasing build number.
  static int? _parseBuildNumber(String tag) {
    // New format: v20260303.1
    if (tag.startsWith('v')) {
      final stripped = tag.substring(1);
      final dotIndex = stripped.indexOf('.');
      if (dotIndex < 0) return null;
      final datePart = stripped.substring(0, dotIndex);
      final seq = int.tryParse(stripped.substring(dotIndex + 1));
      final dateNum = int.tryParse(datePart);
      if (dateNum == null || seq == null || datePart.length != 8) return null;
      return dateNum * 100 + seq;
    }
    // Legacy format: build-N
    if (tag.startsWith('build-')) {
      return int.tryParse(tag.substring(6));
    }
    return null;
  }
}
