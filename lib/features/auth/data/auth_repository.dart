import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';

/// Remembers, on this device, that the person chose "Apply as a teacher"
/// before signing in (Google sign-in leaves the page and comes back).
class TeacherIntentStore {
  const TeacherIntentStore._();

  static const String _key = 'pending_teacher_intent';

  static Future<bool> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> write(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(_key, true);
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {
      // Not being able to remember this is harmless.
    }
  }
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// Where Supabase sends people back to after Google or email links.
  /// This address must be listed in Supabase > Authentication > URL Configuration.
  String? get _origin => kIsWeb ? Uri.base.origin : null;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Returns true when the person must confirm their email before signing in.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
      emailRedirectTo: _origin,
    );
    return response.session == null;
  }

  Future<void> signInWithGoogle() async {
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _origin,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.resetPasswordForEmail(email.trim(), redirectTo: _origin);
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() async {
    await TeacherIntentStore.write(false);
    await _auth.signOut();
  }

  Future<void> setTeacherIntent(bool value) => TeacherIntentStore.write(value);

  /// Asks the database to create a teacher application. The role does not
  /// change until an administrator approves it.
  Future<void> applyAsTeacher({
    required String qualification,
    required String phone,
    String? bio,
  }) async {
    await _client.rpc<dynamic>(
      'apply_as_teacher',
      params: {
        'p_qualification': qualification.trim(),
        'p_bio': (bio ?? '').trim().isEmpty ? null : bio!.trim(),
        'p_phone': phone.trim(),
      },
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
