import 'dart:convert';
import 'package:flutter/material.dart';

enum ApiAuthType { none, bearer, header, basic }

class ApiSyncConfig extends StatefulWidget {
  final String? initialApiUrl;
  final String? initialApiValuePath;
  final String? initialApiAuth;

  const ApiSyncConfig({
    super.key,
    this.initialApiUrl,
    this.initialApiValuePath,
    this.initialApiAuth,
  });

  @override
  State<ApiSyncConfig> createState() => ApiSyncConfigState();
}

class ApiSyncConfigState extends State<ApiSyncConfig> {
  late final TextEditingController _urlController;
  late final TextEditingController _valuePathController;
  late final TextEditingController _bearerTokenController;
  late final TextEditingController _headerNameController;
  late final TextEditingController _headerValueController;
  late final TextEditingController _basicUsernameController;
  late final TextEditingController _basicPasswordController;
  ApiAuthType _authType = ApiAuthType.none;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialApiUrl ?? '');
    _valuePathController =
        TextEditingController(text: widget.initialApiValuePath ?? '');
    _bearerTokenController = TextEditingController();
    _headerNameController = TextEditingController();
    _headerValueController = TextEditingController();
    _basicUsernameController = TextEditingController();
    _basicPasswordController = TextEditingController();
    _parseInitialAuth();
  }

  void _parseInitialAuth() {
    final raw = widget.initialApiAuth;
    if (raw == null || raw.isEmpty) return;
    try {
      final auth = jsonDecode(raw) as Map<String, dynamic>;
      switch (auth['type']) {
        case 'bearer':
          _authType = ApiAuthType.bearer;
          _bearerTokenController.text = auth['token'] as String? ?? '';
        case 'header':
          _authType = ApiAuthType.header;
          _headerNameController.text = auth['name'] as String? ?? '';
          _headerValueController.text = auth['value'] as String? ?? '';
        case 'basic':
          _authType = ApiAuthType.basic;
          _basicUsernameController.text = auth['username'] as String? ?? '';
          _basicPasswordController.text = auth['password'] as String? ?? '';
      }
    } catch (_) {}
  }

  String? get apiUrl {
    final v = _urlController.text.trim();
    return v.isNotEmpty ? v : null;
  }

  String? get apiValuePath {
    final v = _valuePathController.text.trim();
    return v.isNotEmpty ? v : null;
  }

  String? get apiAuth {
    switch (_authType) {
      case ApiAuthType.none:
        return null;
      case ApiAuthType.bearer:
        final token = _bearerTokenController.text.trim();
        if (token.isEmpty) return null;
        return jsonEncode({'type': 'bearer', 'token': token});
      case ApiAuthType.header:
        final name = _headerNameController.text.trim();
        final value = _headerValueController.text.trim();
        if (name.isEmpty) return null;
        return jsonEncode({'type': 'header', 'name': name, 'value': value});
      case ApiAuthType.basic:
        final username = _basicUsernameController.text.trim();
        final password = _basicPasswordController.text.trim();
        if (username.isEmpty) return null;
        return jsonEncode(
            {'type': 'basic', 'username': username, 'password': password});
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _valuePathController.dispose();
    _bearerTokenController.dispose();
    _headerNameController.dispose();
    _headerValueController.dispose();
    _basicUsernameController.dispose();
    _basicPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(Icons.sync,
              size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Auto Sync (Optional)'),
        ],
      ),
      children: [
        TextFormField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'API URL',
            hintText: 'https://api.example.com/price',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _valuePathController,
          decoration: const InputDecoration(
            labelText: 'JSON Value Path',
            hintText: 'data.price',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ApiAuthType>(
          value: _authType,
          decoration: const InputDecoration(labelText: 'Authentication'),
          items: const [
            DropdownMenuItem(value: ApiAuthType.none, child: Text('None')),
            DropdownMenuItem(
                value: ApiAuthType.bearer, child: Text('Bearer Token')),
            DropdownMenuItem(
                value: ApiAuthType.header, child: Text('API Key (Header)')),
            DropdownMenuItem(
                value: ApiAuthType.basic, child: Text('Basic Auth')),
          ],
          onChanged: (v) => setState(() => _authType = v!),
        ),
        const SizedBox(height: 8),
        ..._buildAuthFields(),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _buildAuthFields() {
    switch (_authType) {
      case ApiAuthType.none:
        return [];
      case ApiAuthType.bearer:
        return [
          TextFormField(
            controller: _bearerTokenController,
            decoration: const InputDecoration(
              labelText: 'Token',
              hintText: 'your-api-token',
            ),
            obscureText: true,
          ),
        ];
      case ApiAuthType.header:
        return [
          TextFormField(
            controller: _headerNameController,
            decoration: const InputDecoration(
              labelText: 'Header Name',
              hintText: 'X-API-Key',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _headerValueController,
            decoration: const InputDecoration(
              labelText: 'Header Value',
              hintText: 'your-api-key',
            ),
            obscureText: true,
          ),
        ];
      case ApiAuthType.basic:
        return [
          TextFormField(
            controller: _basicUsernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _basicPasswordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ];
    }
  }
}
