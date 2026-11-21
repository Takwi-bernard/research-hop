import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads the two public settings from assets/env/app.env.
/// Only the Supabase Project URL and the anon (publishable) key belong here.
class Env {
  const Env._();

  static const String _file = 'assets/env/app.env';

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: _file);
    } catch (_) {
      // A missing or unreadable file is reported by [problem].
    }
  }

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  /// The host the app is talking to (not secret), used in error messages.
  static String get host => supabaseUrl.replaceFirst('https://', '');

  /// A human-readable description of what is wrong, or null when all is fine.
  static String? get problem {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return 'SUPABASE_URL and SUPABASE_ANON_KEY are empty. '
          'Open assets/env/app.env, paste your Project URL and your anon '
          '(publishable) key from Supabase > Project Settings > API, '
          'then run the app again.';
    }
    if (supabaseUrl.contains('YOUR-PROJECT') ||
        supabaseAnonKey.contains('YOUR-ANON')) {
      return 'app.env still contains the example values. Put your real '
          'Supabase Project URL and anon key in assets/env/app.env, then '
          'build and deploy again.';
    }
    if (!supabaseUrl.startsWith('https://') ||
        supabaseUrl.replaceFirst('https://', '').contains('/')) {
      return 'SUPABASE_URL must start with https:// '
          '(for example https://abcdxyz.supabase.co) with nothing after '
          '.supabase.co: no slash, no /rest/v1, no /dashboard.';
    }
    if (_isSecretKey(supabaseAnonKey)) {
      return 'The key in SUPABASE_ANON_KEY is a SECRET key (service_role). '
          'It must never be placed in a web app. Use the anon / publishable '
          'key instead, and rotate the secret key in Supabase because it has '
          'now been pasted into a project file.';
    }
    return null;
  }

  static String _read(String key) {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env[key] ?? '').trim();
  }

  static bool _isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(payload);
      return json is Map && json['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
