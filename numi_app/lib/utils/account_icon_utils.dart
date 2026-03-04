import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountIconUtils {
  static const _prefsKeyVersion = 'account_icons_version';
  static const _prefsKeyIcons = 'account_icons_data';

  /// Remote icons: key → SVG string (populated from server or cache).
  static final Map<String, String> _remoteSvgs = {};

  /// Remote mappings: key → keywords list.
  static final List<({String key, List<String> keywords})> _remoteMappings = [];

  /// Cached server version.
  static String? _version;

  /// Get cached version for conditional fetch.
  static String? get version => _version;

  /// Restore cached icons from SharedPreferences on cold start.
  static Future<void> restoreFromCache(SharedPreferences prefs) async {
    _version = prefs.getString(_prefsKeyVersion);
    final json = prefs.getString(_prefsKeyIcons);
    if (json != null) {
      _loadFromJson(json);
    }
  }

  /// Update icons from server response and persist to SharedPreferences.
  static Future<void> loadFromServer(
    List<dynamic> icons,
    String version,
    SharedPreferences prefs,
  ) async {
    final json = jsonEncode(icons);
    _loadFromJson(json);
    _version = version;
    await prefs.setString(_prefsKeyVersion, version);
    await prefs.setString(_prefsKeyIcons, json);
  }

  static void _loadFromJson(String json) {
    final list = jsonDecode(json) as List;
    _remoteSvgs.clear();
    _remoteMappings.clear();
    for (final item in list) {
      final key = item['key'] as String;
      final keywords = List<String>.from(item['keywords'] as List);
      final svg = item['svg'] as String? ?? '';
      _remoteMappings.add((key: key, keywords: keywords));
      if (svg.isNotEmpty) {
        _remoteSvgs[key] = svg;
      }
    }
  }

  /// Build the icon widget for an account. Uses server-provided SVG icons,
  /// returns null if no match (caller shows currency text).
  static Widget? getIconWidget(String accountName, Color iconColor) {
    final lower = accountName.toLowerCase();

    for (final m in _remoteMappings) {
      if (m.keywords.any((k) => lower.contains(k))) {
        final svg = _remoteSvgs[m.key];
        if (svg != null && svg.isNotEmpty) {
          return SvgPicture.string(
            svg,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          );
        }
      }
    }

    return null;
  }
}
