import 'dart:typed_data';

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value as String)?.toLocal();

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : const {};

enum ClassStatus { scheduled, live, ended, cancelled }

ClassStatus classStatusFrom(String? value) => ClassStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ClassStatus.scheduled,
    );

enum ChatMode { locked, teacherOnly, open }

ChatMode chatModeFrom(String? value) {
  switch (value) {
    case 'teacher_only':
      return ChatMode.teacherOnly;
    case 'open':
      return ChatMode.open;
    default:
      return ChatMode.locked;
  }
}

String chatModeToDb(ChatMode mode) {
  switch (mode) {
    case ChatMode.locked:
      return 'locked';
    case ChatMode.teacherOnly:
      return 'teacher_only';
    case ChatMode.open:
      return 'open';
  }
}

enum MessageKind { text, image, audio, file, system }

MessageKind messageKindFrom(String? value) => MessageKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => MessageKind.text,
    );

class ClassSession {
  const ClassSession({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.status,
    required this.chatMode,
    required this.studentsCanSendMedia,
    required this.startedAt,
    required this.endedAt,
  });

  factory ClassSession.fromRow(Map<String, dynamic> row) => ClassSession(
        id: row['id'] as String,
        courseId: row['course_id'] as String,
        courseTitle: (_map(row['courses'])['title'] as String?) ?? 'Course',
        teacherId: (row['teacher_id'] as String?) ?? '',
        title: (row['title'] as String?) ?? '',
        description: (row['description'] as String?) ?? '',
        scheduledAt: _date(row['scheduled_at']) ?? DateTime.now(),
        status: classStatusFrom(row['status'] as String?),
        chatMode: chatModeFrom(row['chat_mode'] as String?),
        studentsCanSendMedia: row['students_can_send_media'] == true,
        startedAt: _date(row['started_at']),
        endedAt: _date(row['ended_at']),
      );

  /// Applies a live change (realtime sends the plain row, without the
  /// course title).
  ClassSession merge(Map<String, dynamic> row) => ClassSession(
        id: id,
        courseId: courseId,
        courseTitle: courseTitle,
        teacherId: (row['teacher_id'] as String?) ?? teacherId,
        title: (row['title'] as String?) ?? title,
        description: (row['description'] as String?) ?? description,
        scheduledAt: _date(row['scheduled_at']) ?? scheduledAt,
        status: row.containsKey('status')
            ? classStatusFrom(row['status'] as String?)
            : status,
        chatMode: row.containsKey('chat_mode')
            ? chatModeFrom(row['chat_mode'] as String?)
            : chatMode,
        studentsCanSendMedia: row.containsKey('students_can_send_media')
            ? row['students_can_send_media'] == true
            : studentsCanSendMedia,
        startedAt: _date(row['started_at']) ?? startedAt,
        endedAt: _date(row['ended_at']) ?? endedAt,
      );

  final String id;
  final String courseId;
  final String courseTitle;
  final String teacherId;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final ClassStatus status;
  final ChatMode chatMode;
  final bool studentsCanSendMedia;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get live => status == ClassStatus.live;
  bool get scheduled => status == ClassStatus.scheduled;
  bool get finished =>
      status == ClassStatus.ended || status == ClassStatus.cancelled;
}

enum SendState { sent, sending, failed }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderLabel,
    required this.kind,
    required this.audience,
    required this.body,
    required this.mediaPath,
    required this.mediaMime,
    required this.mediaSize,
    required this.mediaDurationMs,
    required this.clientId,
    required this.createdAt,
    this.state = SendState.sent,
    this.progress = 0,
    this.pendingBytes,
    this.pendingName,
  });

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as String,
        senderId: (row['sender_id'] as String?) ?? '',
        senderRole: (row['sender_role'] as String?) ?? 'student',
        senderLabel: (row['sender_label'] as String?) ?? 'Student',
        kind: messageKindFrom(row['kind'] as String?),
        audience: (row['audience'] as String?) ?? 'class',
        body: row['body'] as String?,
        mediaPath: row['media_path'] as String?,
        mediaMime: row['media_mime'] as String?,
        mediaSize: (row['media_size_bytes'] as num?)?.toInt(),
        mediaDurationMs: (row['media_duration_ms'] as num?)?.toInt(),
        clientId: (row['client_id'] as String?) ?? '',
        createdAt: _date(row['created_at']) ?? DateTime.now(),
      );

  final String id;
  final String senderId;
  final String senderRole;
  final String senderLabel;
  final MessageKind kind;
  final String audience;
  final String? body;
  final String? mediaPath;
  final String? mediaMime;
  final int? mediaSize;
  final int? mediaDurationMs;
  final String clientId;
  final DateTime createdAt;

  // Local-only state for messages still on their way.
  SendState state;
  double progress;
  Uint8List? pendingBytes;
  String? pendingName;

  bool get fromInstructor => senderRole == 'teacher';
  bool get privateToInstructor => audience == 'teacher';
}

class HandRaise {
  const HandRaise({
    required this.id,
    required this.studentId,
    required this.label,
    required this.createdAt,
  });

  factory HandRaise.fromRow(Map<String, dynamic> row) => HandRaise(
        id: row['id'] as String,
        studentId: row['student_id'] as String,
        label: (row['student_label'] as String?) ?? 'Student',
        createdAt: _date(row['created_at']) ?? DateTime.now(),
      );

  final String id;
  final String studentId;
  final String label;
  final DateTime createdAt;
}

class Announcement {
  const Announcement({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory Announcement.fromRow(Map<String, dynamic> row) => Announcement(
        id: row['id'] as String,
        authorId: (row['author_id'] as String?) ?? '',
        title: (row['title'] as String?) ?? '',
        body: (row['body'] as String?) ?? '',
        createdAt: _date(row['created_at']) ?? DateTime.now(),
      );

  final String id;
  final String authorId;
  final String title;
  final String body;
  final DateTime createdAt;
}
