import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/utils/upload_exception.dart';
import '../../../core/utils/web_files.dart';
import 'classroom_models.dart';

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) Map<String, dynamic>.from(item as Map)];
}

const _sessionColumns =
    'id, course_id, teacher_id, title, description, scheduled_at, status, '
    'chat_mode, students_can_send_media, started_at, ended_at, courses(title)';

const _messageColumns =
    'id, session_id, sender_id, sender_role, sender_label, kind, audience, '
    'body, media_path, media_mime, media_size_bytes, media_duration_ms, '
    'client_id, created_at';

class ClassroomRepository {
  ClassroomRepository(this._client);

  final SupabaseClient _client;

  String get myId => _client.auth.currentUser?.id ?? '';

  // ---- reading ----

  Future<ClassSession> session(String id) async {
    final row = await _client
        .from('class_sessions')
        .select(_sessionColumns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const UploadException('This class was not found.');
    }
    return ClassSession.fromRow(Map<String, dynamic>.from(row));
  }

  Future<List<ChatMessage>> messages(String sessionId) async {
    final rows = await _client
        .from('session_messages')
        .select(_messageColumns)
        .eq('session_id', sessionId)
        .order('created_at', ascending: false)
        .limit(200);
    final items = [for (final r in _list(rows)) ChatMessage.fromRow(r)];
    return items.reversed.toList();
  }

  Future<List<HandRaise>> hands(String sessionId) async {
    final rows = await _client
        .from('session_hand_raises')
        .select('id, student_id, student_label, created_at')
        .eq('session_id', sessionId)
        .filter('resolved_at', 'is', null)
        .order('created_at');
    return [for (final r in _list(rows)) HandRaise.fromRow(r)];
  }

  Future<Set<String>> mutedIds(String sessionId) async {
    final rows = await _client
        .from('session_mutes')
        .select('student_id')
        .eq('session_id', sessionId);
    return {for (final r in _list(rows)) r['student_id'] as String};
  }

  // ---- sending ----

  Future<ChatMessage> insertMessage({
    required String sessionId,
    required String clientId,
    required MessageKind kind,
    required String audience,
    String? body,
    String? mediaPath,
    String? mediaMime,
    int? mediaSize,
    int? durationMs,
  }) async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'sender_id': myId,
      'kind': kind.name,
      'audience': audience,
      'client_id': clientId,
      if (body != null) 'body': body,
      if (mediaPath != null) 'media_path': mediaPath,
      if (mediaMime != null) 'media_mime': mediaMime,
      if (mediaSize != null) 'media_size_bytes': mediaSize,
      if (durationMs != null) 'media_duration_ms': durationMs,
    };
    try {
      final row = await _client
          .from('session_messages')
          .insert(payload)
          .select(_messageColumns)
          .single();
      return ChatMessage.fromRow(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      // The same message was already saved (a retry after a dropped
      // connection): fetch it instead of failing.
      if (error.code == '23505') {
        final row = await _client
            .from('session_messages')
            .select(_messageColumns)
            .eq('sender_id', myId)
            .eq('client_id', clientId)
            .single();
        return ChatMessage.fromRow(Map<String, dynamic>.from(row));
      }
      rethrow;
    }
  }

  /// Uploads a picture, voice note or file and returns where it was stored.
  Future<String> uploadMedia({
    required String sessionId,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    required void Function(double fraction) onProgress,
  }) async {
    var auth = _client.auth.currentSession;
    if (auth == null) throw const UploadException('Please sign in again.');
    if (auth.isExpired) {
      final refreshed = await _client.auth.refreshSession();
      auth = refreshed.session ?? auth;
    }
    final safeExt = extension.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final path =
        '$sessionId/$myId-${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    await uploadWithProgress(
      url: '${Env.supabaseUrl}/storage/v1/object/chat-media/$path',
      headers: {
        'Authorization': 'Bearer ${auth.accessToken}',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': mimeType,
        'x-upsert': 'false',
        'cache-control': 'max-age=3600',
      },
      bytes: bytes,
      onProgress: (sent, total) => onProgress(total == 0 ? 0 : sent / total),
    );
    return path;
  }

  Future<String> mediaUrl(String path) =>
      _client.storage.from('chat-media').createSignedUrl(path, 3600);

  // ---- class controls (teacher) ----

  Future<void> startClass(String id) =>
      _client.rpc('start_session', params: {'p_session': id});

  Future<void> endClass(String id) =>
      _client.rpc('end_session', params: {'p_session': id});

  Future<void> cancelClass(String id) =>
      _client.rpc('cancel_session', params: {'p_session': id});

  Future<void> setChatMode(String id, ChatMode mode, bool allowMedia) =>
      _client.rpc('set_chat_mode', params: {
        'p_session': id,
        'p_mode': chatModeToDb(mode),
        'p_media': allowMedia,
      });

  Future<void> resolveHand(String handId) => _client
      .from('session_hand_raises')
      .update({'resolved_at': DateTime.now().toUtc().toIso8601String()}).eq(
        'id',
        handId,
      );

  Future<void> muteStudent(String sessionId, String studentId) async {
    try {
      await _client.from('session_mutes').insert({
        'session_id': sessionId,
        'student_id': studentId,
        'muted_by': myId,
      });
    } on PostgrestException catch (error) {
      // Already muted: nothing to do.
      if (error.code != '23505') rethrow;
    }
  }

  Future<void> unmuteStudent(String sessionId, String studentId) => _client
      .from('session_mutes')
      .delete()
      .eq('session_id', sessionId)
      .eq('student_id', studentId);

  // ---- student ----

  Future<void> raiseHand(String id) =>
      _client.rpc('raise_hand', params: {'p_session': id});

  Future<void> lowerHand(String id) =>
      _client.rpc('lower_hand', params: {'p_session': id});

  // ---- announcements ----

  Future<List<Announcement>> announcements(String courseId) async {
    final rows = await _client
        .from('course_announcements')
        .select('id, author_id, title, body, created_at')
        .eq('course_id', courseId)
        .order('created_at', ascending: false)
        .limit(30);
    return [for (final r in _list(rows)) Announcement.fromRow(r)];
  }

  Future<void> postAnnouncement(
    String courseId,
    String title,
    String body,
  ) =>
      _client.from('course_announcements').insert({
        'course_id': courseId,
        'author_id': myId,
        'title': title,
        'body': body,
      });

  Future<void> deleteAnnouncement(String id) =>
      _client.from('course_announcements').delete().eq('id', id);
}
