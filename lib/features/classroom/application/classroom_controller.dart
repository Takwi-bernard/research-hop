import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/errors.dart';
import '../data/classroom_models.dart';
import '../data/classroom_repository.dart';

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) => [
        for (var i = from; i < to; i++) bytes[i].toRadixString(16).padLeft(2, '0'),
      ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

String chatErrorText(Object error) {
  if (error is PostgrestException) {
    final text = error.message.toLowerCase();
    if (text.contains('row-level security') || text.contains('violates')) {
      return 'You cannot send messages right now.';
    }
  }
  if (error is StorageException) {
    return 'That file could not be uploaded. Check its type and size.';
  }
  return friendlyError(error);
}

/// Everything the class room needs, kept in one place: the class itself,
/// its messages, raised hands and muted students. It listens to live
/// changes and falls back to checking every few seconds when the live
/// connection is down (weak networks).
class ClassRoomController extends ChangeNotifier {
  ClassRoomController({
    required SupabaseClient client,
    required this.repo,
    required this.sessionId,
    required this.isTeacher,
  }) : _client = client;

  final SupabaseClient _client;
  final ClassroomRepository repo;
  final String sessionId;
  final bool isTeacher;

  ClassSession? session;
  List<ChatMessage> messages = [];
  List<HandRaise> hands = [];
  Set<String> mutedIds = {};
  bool loading = true;
  Object? loadError;
  bool connected = false;
  bool busy = false;

  RealtimeChannel? _channel;
  Timer? _poll;
  bool _disposed = false;

  String get myId => repo.myId;
  bool get iAmMuted => mutedIds.contains(myId);
  bool get myHandUp => hands.any((h) => h.studentId == myId);

  /// Who may read a message a student sends right now.
  String get studentAudience =>
      session?.chatMode == ChatMode.teacherOnly ? 'teacher' : 'class';

  /// True when the current person can type a message right now.
  bool get canWrite {
    final s = session;
    if (s == null || !s.live) return false;
    if (isTeacher) return true;
    if (iAmMuted) return false;
    return s.chatMode != ChatMode.locked;
  }

  bool get canSendMedia {
    final s = session;
    if (!canWrite || s == null) return false;
    return isTeacher || s.studentsCanSendMedia;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    await _loadAll();
    _subscribe();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!connected) _refresh();
    });
  }

  Future<void> _loadAll() async {
    loading = messages.isEmpty && session == null;
    _changed();
    try {
      final results = await Future.wait<dynamic>([
        repo.session(sessionId),
        repo.messages(sessionId),
        repo.hands(sessionId),
        repo.mutedIds(sessionId),
      ]);
      session = results[0] as ClassSession;
      _mergeMessages(results[1] as List<ChatMessage>);
      hands = results[2] as List<HandRaise>;
      mutedIds = results[3] as Set<String>;
      loadError = null;
    } catch (error) {
      if (session == null) loadError = error;
    }
    loading = false;
    _changed();
  }

  Future<void> retryLoad() => _loadAll();

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<dynamic>([
        repo.session(sessionId),
        repo.messages(sessionId),
        repo.hands(sessionId),
        repo.mutedIds(sessionId),
      ]);
      session = results[0] as ClassSession;
      _mergeMessages(results[1] as List<ChatMessage>);
      hands = results[2] as List<HandRaise>;
      mutedIds = results[3] as Set<String>;
      _changed();
    } catch (_) {
      // Stay quiet: the next check tries again.
    }
  }

  void _mergeMessages(List<ChatMessage> fetched) {
    final byClient = {for (final m in fetched) m.clientId};
    final pending = messages.where(
      (m) => m.state != SendState.sent && !byClient.contains(m.clientId),
    );
    final merged = [...fetched, ...pending]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    messages = merged;
  }

  void _subscribe() {
    final channel = _client.channel('room-$sessionId');
    PostgresChangeFilter bySession(String column) => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: column,
          value: sessionId,
        );

    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'session_messages',
        filter: bySession('session_id'),
        callback: (payload) => _onMessage(payload.newRecord),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'class_sessions',
        filter: bySession('id'),
        callback: (payload) {
          final current = session;
          if (current == null) return;
          session = current.merge(payload.newRecord);
          _changed();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'session_hand_raises',
        filter: bySession('session_id'),
        callback: (_) => _reloadHands(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'session_mutes',
        filter: bySession('session_id'),
        callback: (_) => _reloadMutes(),
      )
      ..subscribe((status, error) {
        final up = status == RealtimeSubscribeStatus.subscribed;
        if (up != connected) {
          connected = up;
          _changed();
          // After a drop, catch up on anything that was missed.
          if (up) _refresh();
        }
      });
    _channel = channel;
  }

  void _onMessage(Map<String, dynamic> row) {
    if (row['id'] == null) return;
    final message = ChatMessage.fromRow(row);
    if (messages.any((m) => m.id == message.id)) return;
    final index = messages.indexWhere(
      (m) => m.clientId == message.clientId && m.state != SendState.sent,
    );
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages = [...messages, message];
    }
    _changed();
  }

  Future<void> _reloadHands() async {
    try {
      hands = await repo.hands(sessionId);
      _changed();
    } catch (_) {}
  }

  Future<void> _reloadMutes() async {
    try {
      mutedIds = await repo.mutedIds(sessionId);
      _changed();
    } catch (_) {}
  }

  // ---- sending ----

  ChatMessage _pending({
    required MessageKind kind,
    required String audience,
    String? body,
    String? mime,
    int? size,
    int? durationMs,
    Uint8List? bytes,
    String? name,
  }) {
    final clientId = _newUuid();
    return ChatMessage(
      id: 'local-$clientId',
      senderId: myId,
      senderRole: isTeacher ? 'teacher' : 'student',
      senderLabel: isTeacher ? 'Instructor' : 'You',
      kind: kind,
      audience: audience,
      body: body,
      mediaPath: null,
      mediaMime: mime,
      mediaSize: size,
      mediaDurationMs: durationMs,
      clientId: clientId,
      createdAt: DateTime.now(),
      state: SendState.sending,
      pendingBytes: bytes,
      pendingName: name,
    );
  }

  String get _audience => isTeacher ? 'class' : studentAudience;

  Future<void> sendText(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final message = _pending(
      kind: MessageKind.text,
      audience: _audience,
      body: clean,
    );
    messages = [...messages, message];
    _changed();
    await _deliver(message);
  }

  Future<void> sendMedia({
    required MessageKind kind,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    required String name,
    int? durationMs,
  }) async {
    final message = _pending(
      kind: kind,
      audience: _audience,
      body: kind == MessageKind.file ? name : null,
      mime: mimeType,
      size: bytes.length,
      durationMs: durationMs,
      bytes: bytes,
      name: extension,
    );
    messages = [...messages, message];
    _changed();
    await _deliver(message);
  }

  Future<void> retry(ChatMessage message) async {
    if (message.state != SendState.failed) return;
    message.state = SendState.sending;
    message.progress = 0;
    _changed();
    await _deliver(message);
  }

  void discard(ChatMessage message) {
    messages = messages.where((m) => m.clientId != message.clientId).toList();
    _changed();
  }

  Future<void> _deliver(ChatMessage message) async {
    try {
      String? path;
      if (message.kind == MessageKind.image ||
          message.kind == MessageKind.audio ||
          message.kind == MessageKind.file) {
        final bytes = message.pendingBytes;
        if (bytes == null) throw StateError('nothing to upload');
        path = await repo.uploadMedia(
          sessionId: sessionId,
          bytes: bytes,
          mimeType: message.mediaMime ?? 'application/octet-stream',
          extension: message.pendingName ?? 'bin',
          onProgress: (fraction) {
            message.progress = fraction;
            _changed();
          },
        );
      }
      final saved = await repo.insertMessage(
        sessionId: sessionId,
        clientId: message.clientId,
        kind: message.kind,
        audience: message.audience,
        body: message.body,
        mediaPath: path,
        mediaMime: message.mediaMime,
        mediaSize: message.mediaSize,
        durationMs: message.mediaDurationMs,
      );
      final index = messages.indexWhere((m) => m.clientId == message.clientId);
      if (index >= 0) {
        messages[index] = saved;
      } else if (!messages.any((m) => m.id == saved.id)) {
        messages = [...messages, saved];
      }
      // If the live copy arrived first there may now be two: keep one.
      final seen = <String>{};
      messages = [
        for (final m in messages)
          if (seen.add(m.id)) m,
      ];
      _changed();
    } catch (error) {
      message.state = SendState.failed;
      lastError = chatErrorText(error);
      _changed();
    }
  }

  /// The latest sending problem, shown once by the page.
  String? lastError;

  // ---- class controls ----

  Future<String?> _run(Future<void> Function() action) async {
    busy = true;
    _changed();
    try {
      await action();
      await _refresh();
      return null;
    } catch (error) {
      return chatErrorText(error);
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<String?> startClass() => _run(() => repo.startClass(sessionId));
  Future<String?> endClass() => _run(() => repo.endClass(sessionId));

  Future<String?> setMode(ChatMode mode, bool allowMedia) =>
      _run(() => repo.setChatMode(sessionId, mode, allowMedia));

  Future<String?> resolveHand(HandRaise hand) =>
      _run(() => repo.resolveHand(hand.id));

  Future<String?> mute(String studentId) async {
    final error = await _run(() async {
      await repo.muteStudent(sessionId, studentId);
      final raised = hands.where((h) => h.studentId == studentId);
      for (final hand in raised) {
        await repo.resolveHand(hand.id);
      }
    });
    return error;
  }

  Future<String?> unmute(String studentId) =>
      _run(() => repo.unmuteStudent(sessionId, studentId));

  Future<String?> toggleHand() => _run(
        () => myHandUp ? repo.lowerHand(sessionId) : repo.raiseHand(sessionId),
      );

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    final channel = _channel;
    if (channel != null) _client.removeChannel(channel);
    super.dispose();
  }
}
