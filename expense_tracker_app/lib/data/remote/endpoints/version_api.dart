import 'package:dio/dio.dart';

/// Checks GitHub Releases for the latest Numi build.
/// Tag format: "build-NNNN" where NNNN = github.run_number.
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

  /// Returns the latest release's build number and download page URL,
  /// or null if unavailable / token missing / parse error.
  Future<({int buildNumber, String htmlUrl})?> getLatestRelease() async {
    try {
      final resp = await _dio.get(
          '/repos/Steaunk/expense-tracker/releases/latest');
      final tag = (resp.data['tag_name'] as String?) ?? '';
      // tag = "build-NNNN"
      final parts = tag.split('-');
      if (parts.length != 2) return null;
      final build = int.tryParse(parts[1]);
      if (build == null) return null;
      final url = (resp.data['html_url'] as String?) ?? '';
      return (buildNumber: build, htmlUrl: url);
    } catch (_) {
      return null;
    }
  }
}
