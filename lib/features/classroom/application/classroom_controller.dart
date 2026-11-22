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

  /// Who has read each message (message id -> readers).
  Map<String, List<Receipt>> receipts = {};

  /// The student's most recent hand, answered or not.
  HandRaise? myHand;
  String? _dismissedLaterId;

  /// People currently typing (id -> who, until when).
  final Map<String, _Typer> _typers = {};
  Timer? _typeSweep;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  String? _myLabel;
  Timer? _readTimer;

  bool loading = true;
  Object? loadError;
  bool connected = false;
  bool busy = false;

  RealtimeChannel? _channel;
  Timer? _poll;
  bool _disposed = false;

  String get myId => repo.myId;
  bool get iAmMuted => mutedIds.contains(myId);

  /// A hand that is up and still waiting for an answer.
  bool get myHandUp => hands.any((h) => h.studentId == myId && h.waiting);

  /// The instructor gave this student the floor.
  bool get hasFloor => !isTeacher && (myHand?.hasFloor ?? false);

  /// The instructor answered "later" and the student has not closed the note.
  bool get showLaterNote {
    final hand = myHand;
    if (isTeacher || hand == null || !hand.deferred) return false;
    if (hand.id == _dismissedLaterId) return false;
    final at = hand.respondedAt;
    return at == null ||
        DateTime.now().difference(at) < const Duration(minutes: 3);
  }

  void dismissLaterNote() {
    _dismissedLaterId = myHand?.id;
    _changed();
  }

  /// Hands still waiting for the instructor, oldest first.
  List<HandRaise> get waitingHands => [
        for (final h in hands)
          if (h.waiting) h,
      ];

  /// The student who currently has the floor (instructor view).
  HandRaise? get floorHolder {
    for (final h in hands) {
      if (h.hasFloor) return h;
    }
    return null;
  }

  /// Who may read a message a student sends right now.
  String get studentAudience {
    if (hasFloor) return 'class';
    return session?.chatMode == ChatMode.teacherOnly ? 'teacher' : 'class';
  }

  /// Names of people typing right now (never includes this person).
  List<String> get typingNames => [
        for (final t in _typers.values)
          if (t.until.isAfter(DateTime.now())) t.name,
      ];

  /// People other than the sender who have read this message.
  List<Receipt> readersOf(ChatMessage message) => [
        for (final r in receipts[message.id] ?? const <Receipt>[])
          if (r.readerId != message.senderId) r,
      ];

  /// True when the current person can type a message right now.
  bool get canWrite {
    final s = session;
    if (s == null || !s.live) return false;
    if (isTeacher) return true;
    if (iAmMuted) return false;
    if (hasFloor) return true;
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
    _loadMyLabel();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!connected) _refresh();
    });
  }

  Future<void> _fetch() async {
    final results = await Future.wait<dynamic>([
      repo.session(sessionId),
      repo.messages(sessionId),
      repo.hands(sessionId),
      repo.mutedIds(sessionId),
      _optional(() => repo.receipts(sessionId)),
      isTeacher ? Future<HandRaise?>.value(null) : _optional(() => repo.myLatestHand(sessionId)),
    ]);
    session = results[0] as ClassSession;
    _mergeMessages(results[1] as List<ChatMessage>);
    hands = results[2] as List<HandRaise>;
    mutedIds = results[3] as Set<String>;
    final fetchedReceipts = results[4] as List<Receipt>?;
    if (fetchedReceipts != null) _setReceipts(fetchedReceipts);
    myHand = results[5] as HandRaise?;
  }

  /// Receipts and the latest hand are extras: if they fail (for example
  /// before migration 006 is run) the class room still works.
  Future<T?> _optional<T>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  void _setReceipts(List<Receipt> list) {
    final map = <String, List<Receipt>>{};
    for (final r in list) {
      map.putIfAbsent(r.messageId, () => []).add(r);
    }
    receipts = map;
  }

  Future<void> _loadAll() async {
    loading = messages.isEmpty && session == null;
    _changed();
    try {
      await _fetch();
      loadError = null;
    } catch (error) {
      if (session == null) loadError = error;
    }
    loading = false;
    _changed();
    _markReadSoon();
  }

  Future<void> retryLoad() => _loadAll();

  Future<void> _refresh() async {
    try {
      await _fetch();
      _changed();
      _markReadSoon();
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
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'message_reads',
        filter: bySession('session_id'),
        callback: (payload) => _onReceipt(payload.newRecord),
      )
      ..onBroadcast(
        event: 'typing',
        callback: (payload) => _onTyping(payload),
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
    _typers.remove(message.senderId);
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
    if (message.senderId != myId) _markReadSoon();
  }

  void _onReceipt(Map<String, dynamic> row) {
    if (row['message_id'] == null) return;
    final receipt = Receipt.fromRow(row);
    final list = receipts[receipt.messageId] ?? [];
    if (list.any((r) => r.readerId == receipt.readerId)) return;
    receipts = {
      ...receipts,
      receipt.messageId: [...list, receipt],
    };
    _changed();
  }

  /// Tells the server this person has read what is on screen. Waits a
  /// moment so a burst of messages makes only one call.
  void _markReadSoon() {
    if (_disposed) return;
    final s = session;
    if (s == null || s.scheduled) return;
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 700), () async {
      final unread = messages.any((m) =>
          m.senderId != myId &&
          m.state == SendState.sent &&
          m.kind != MessageKind.system &&
          (isTeacher || m.audience == 'class') &&
          !(receipts[m.id]?.any((r) => r.readerId == myId) ?? false));
      if (!unread) return;
      try {
        await repo.markRead(sessionId);
      } catch (_) {}
    });
  }

  // ---- typing ----

  Future<void> _loadMyLabel() async {
    if (isTeacher) {
      _myLabel = 'Instructor';
      return;
    }
    try {
      _myLabel = await repo.myLabel();
    } catch (_) {
      _myLabel = 'A student';
    }
  }

  /// Called while this person types. Sends at most one signal every 2.5 s.
  void notifyTyping() {
    final channel = _channel;
    if (channel == null || !connected || !canWrite) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) {
      return;
    }
    _lastTypingSent = now;
    unawaited(() async {
      try {
        await channel.sendBroadcastMessage(
          event: 'typing',
          payload: {
            'id': myId,
            'name': _myLabel ?? (isTeacher ? 'Instructor' : 'A student'),
            'teacher': isTeacher,
            'audience': isTeacher ? 'class' : studentAudience,
          },
        );
      } catch (_) {
        // Typing signals are best effort.
      }
    }());
  }

  void _onTyping(Map<String, dynamic> raw) {
    final data = raw['payload'] is Map
        ? Map<String, dynamic>.from(raw['payload'] as Map)
        : raw;
    final id = data['id'] as String?;
    if (id == null || id == myId) return;
    final fromTeacher = data['teacher'] == true;
    // A student's private reply to the instructor is not shown to others.
    if (!fromTeacher && data['audience'] == 'teacher' && !isTeacher) return;
    _typers[id] = _Typer(
      fromTeacher ? 'Instructor' : ((data['name'] as String?) ?? 'A student'),
      DateTime.now().add(const Duration(seconds: 4)),
    );
    _typeSweep ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _typers.length;
      _typers.removeWhere((_, t) => !t.until.isAfter(DateTime.now()));
      if (_typers.isEmpty) {
        _typeSweep?.cancel();
        _typeSweep = null;
      }
      if (before != _typers.length) _changed();
    });
    _changed();
  }

  Future<void> _reloadHands() async {
    try {
      hands = await repo.hands(sessionId);
      if (!isTeacher) myHand = await repo.myLatestHand(sessionId);
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

  Future<String?> giveFloor(HandRaise hand) =>
      _run(() => repo.giveFloor(hand.id));

  Future<String?> deferHand(HandRaise hand) =>
      _run(() => repo.deferHand(hand.id));

  /// The instructor takes the floor back, or the student hands it back.
  Future<String?> endFloor(HandRaise hand) =>
      _run(() => repo.endFloor(hand.id));

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
    _readTimer?.cancel();
    _typeSweep?.cancel();
    final channel = _channel;
    if (channel != null) _client.removeChannel(channel);
    super.dispose();
  }
}

class _Typer {
  _Typer(this.name, this.until);
  final String name;
  final DateTime until;
}
