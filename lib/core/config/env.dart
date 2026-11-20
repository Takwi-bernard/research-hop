import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads the two public settings from assets/env/app.env.
/// Only the Supabase Project URL and the anon (publishable) key belong here.
class Env {
  const Env._();

  static const String _file = '.env';

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: _file);
    } catch (_) {
      // A missing or unreadable file is reported by [problem].
    }
  }

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  /// A human-readable description of what is wrong, or null when all is fine.
  static String? get problem {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return 'SUPABASE_URL and SUPABASE_ANON_KEY are empty. '
          'Open assets/env/app.env, paste your Project URL and your anon '
          '(publishable) key from Supabase > Project Settings > API, '
          'then run the app again.';
    }
    if (!supabaseUrl.startsWith('https://')) {
      return 'SUPABASE_URL must start with https:// '
          '(for example https://abcdxyz.supabase.co).';
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
