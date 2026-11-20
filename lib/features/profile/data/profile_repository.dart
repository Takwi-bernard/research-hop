import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/providers.dart';
import '../../../core/utils/upload_exception.dart';
import '../../../core/utils/web_files.dart';

String? _nullIfEmpty(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  User? get user => _client.auth.currentUser;

  /// "google", "email", ...
  String get signInMethod {
    final provider = user?.appMetadata['provider'];
    return provider is String ? provider : 'email';
  }

  Future<void> updateDetails({
    required String userId,
    required String fullName,
    String? phone,
    String? city,
  }) async {
    await _client.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': _nullIfEmpty(phone),
      'city': _nullIfEmpty(city),
    }).eq('id', userId);
  }

  /// [bytes] must already be a small JPEG (see compressImage).
  Future<void> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String? oldUrl,
    required void Function(double fraction) onProgress,
  }) async {
    var session = _client.auth.currentSession;
    if (session == null) throw const UploadException('Please sign in again.');
    if (session.isExpired) {
      final refreshed = await _client.auth.refreshSession();
      session = refreshed.session ?? session;
    }

    final path = '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await uploadWithProgress(
      url: '${Env.supabaseUrl}/storage/v1/object/avatars/$path',
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': 'image/jpeg',
        'x-upsert': 'false',
        'cache-control': 'max-age=31536000',
      },
      bytes: bytes,
      onProgress: (sent, total) => onProgress(total == 0 ? 0 : sent / total),
    );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl}).eq('id', userId);
    await _removeFile(oldUrl);
  }

  Future<void> removeAvatar({
    required String userId,
    required String? oldUrl,
  }) async {
    await _client.from('profiles').update({'avatar_url': null}).eq('id', userId);
    await _removeFile(oldUrl);
  }

  Future<void> _removeFile(String? url) async {
    if (url == null || url.isEmpty) return;
    const marker = '/avatars/';
    final index = url.indexOf(marker);
    if (index < 0) return;
    final path = Uri.decodeComponent(url.substring(index + marker.length));
    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // A leftover picture is harmless.
    }
  }

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
