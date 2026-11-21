import '../../admin/data/admin_models.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

class CatalogCourse {
  const CatalogCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.durationLabel,
    required this.feeXaf,
  });

  factory CatalogCourse.fromRow(Map<String, dynamic> row) => CatalogCourse(
        id: row['id'] as String,
        title: (row['title'] as String?) ?? '',
        description: (row['description'] as String?) ?? '',
        category: row['category'] as String?,
        level: row['level'] as String?,
        durationLabel: row['duration_label'] as String?,
        feeXaf: (row['fee_xaf'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String title;
  final String description;
  final String? category;
  final String? level;
  final String? durationLabel;
  final int feeXaf;

  String get levelLabel => level == null
      ? ''
      : level!.substring(0, 1).toUpperCase() + level!.substring(1);
}

class MyRegistration {
  const MyRegistration({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    required this.feeXaf,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.createdAt,
    required this.rejectionReason,
  });

  factory MyRegistration.fromRow(Map<String, dynamic> row) => MyRegistration(
        id: row['id'] as String,
        courseId: row['course_id'] as String,
        courseTitle: (_map(row['courses'])['title'] as String?) ?? 'Course',
        status: regStatusFrom(row['status'] as String?),
        feeXaf: (row['fee_xaf'] as num?)?.toInt() ?? 0,
        fullName: (row['full_name'] as String?) ?? '',
        phone: (row['phone'] as String?) ?? '',
        city: row['city'] as String?,
        createdAt: _date(row['created_at']),
        rejectionReason: row['rejection_reason'] as String?,
      );

  final String id;
  final String courseId;
  final String courseTitle;
  final RegStatus status;
  final int feeXaf;
  final String fullName;
  final String phone;
  final String? city;
  final DateTime? createdAt;
  final String? rejectionReason;
}

class ClassItem {
  const ClassItem({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.title,
    required this.scheduledAt,
    required this.live,
  });

  factory ClassItem.fromRow(Map<String, dynamic> row) => ClassItem(
        id: row['id'] as String,
        courseId: row['course_id'] as String,
        courseTitle: (_map(row['courses'])['title'] as String?) ?? 'Course',
        title: (row['title'] as String?) ?? '',
        scheduledAt: _date(row['scheduled_at']) ?? DateTime.now(),
        live: row['status'] == 'live',
      );

  final String id;
  final String courseId;
  final String courseTitle;
  final String title;
  final DateTime scheduledAt;
  final bool live;
}

class CourseContent {
  const CourseContent({required this.notes, required this.materials});

  final List<CourseNote> notes;
  final List<CourseMaterial> materials;
}

class PaymentProgress {
  const PaymentProgress({
    required this.id,
    required this.state,
    required this.failureReason,
  });

  factory PaymentProgress.fromRow(Map<String, dynamic> row) {
    final status = row['status'] as String?;
    return PaymentProgress(
      id: row['id'] as String,
      state: status == 'successful'
          ? PayState.successful
          : status == 'failed'
              ? PayState.failed
              : PayState.pending,
      failureReason: row['failure_reason'] as String?,
    );
  }

  final String id;
  final PayState state;
  final String? failureReason;
}

/// What the "pay" button gets back from the payment function.
class PaymentStart {
  const PaymentStart({required this.paymentId, this.ussdCode, this.operator});

  final String paymentId;
  final String? ussdCode;
  final String? operator;
}

/// The registration that matters for a course: a live one if there is one,
/// otherwise the most recent closed one (rejected or cancelled).
MyRegistration? registrationFor(List<MyRegistration> all, String courseId) {
  MyRegistration? closed;
  for (final r in all) {
    if (r.courseId != courseId) continue;
    if (r.status == RegStatus.awaitingPayment ||
        r.status == RegStatus.paid ||
        r.status == RegStatus.approved) {
      return r;
    }
    closed ??= r;
  }
  return closed;
}
