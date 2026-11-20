import '../../auth/domain/models.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) _map(item)];
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

// ---------------------------------------------------------------------------
// Courses
// ---------------------------------------------------------------------------

enum CourseStatus { draft, published, archived }

CourseStatus courseStatusFrom(String? value) => CourseStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => CourseStatus.draft,
    );

String courseStatusLabel(CourseStatus status) {
  switch (status) {
    case CourseStatus.draft:
      return 'Draft';
    case CourseStatus.published:
      return 'Published';
    case CourseStatus.archived:
      return 'Archived';
  }
}

class TeacherRef {
  const TeacherRef({required this.id, required this.name});
  final String id;
  final String name;
}

class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.durationLabel,
    required this.feeXaf,
    required this.status,
    required this.teachers,
    required this.approvedStudents,
    required this.waitingApproval,
  });

  factory CourseSummary.fromRow(Map<String, dynamic> row) {
    final regs = _rows(row['registrations']);
    return CourseSummary(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      category: row['category'] as String?,
      level: row['level'] as String?,
      durationLabel: row['duration_label'] as String?,
      feeXaf: (row['fee_xaf'] as num?)?.toInt() ?? 0,
      status: courseStatusFrom(row['status'] as String?),
      teachers: [
        for (final item in _rows(row['course_teachers']))
          TeacherRef(
            id: item['teacher_id'] as String,
            name: ((_map(item['profiles'])['full_name']) as String?) ?? '',
          ),
      ],
      approvedStudents: regs.where((r) => r['status'] == 'approved').length,
      waitingApproval: regs.where((r) => r['status'] == 'paid').length,
    );
  }

  final String id;
  final String title;
  final String description;
  final String? category;
  final String? level;
  final String? durationLabel;
  final int feeXaf;
  final CourseStatus status;
  final List<TeacherRef> teachers;
  final int approvedStudents;
  final int waitingApproval;
}

class CourseNote {
  const CourseNote({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
  });

  factory CourseNote.fromRow(Map<String, dynamic> row) => CourseNote(
        id: row['id'] as String,
        title: (row['title'] as String?) ?? '',
        description: (row['description'] as String?) ?? '',
        position: (row['position'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String title;
  final String description;
  final int position;
}

class CourseMaterial {
  const CourseMaterial({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory CourseMaterial.fromRow(Map<String, dynamic> row) => CourseMaterial(
        id: row['id'] as String,
        moduleId: row['module_id'] as String?,
        title: (row['title'] as String?) ?? '',
        storagePath: (row['storage_path'] as String?) ?? '',
        mimeType: row['mime_type'] as String?,
        sizeBytes: (row['size_bytes'] as num?)?.toInt(),
      );

  final String id;
  final String? moduleId;
  final String title;
  final String storagePath;
  final String? mimeType;
  final int? sizeBytes;
}

class CourseDetail {
  const CourseDetail({
    required this.summary,
    required this.notes,
    required this.materials,
  });

  factory CourseDetail.fromRow(Map<String, dynamic> row) {
    final notes = [
      for (final r in _rows(row['course_modules'])) CourseNote.fromRow(r),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return CourseDetail(
      summary: CourseSummary.fromRow(row),
      notes: notes,
      materials: [
        for (final r in _rows(row['course_materials']))
          CourseMaterial.fromRow(r),
      ],
    );
  }

  final CourseSummary summary;
  final List<CourseNote> notes;
  final List<CourseMaterial> materials;
}

// ---------------------------------------------------------------------------
// Teachers
// ---------------------------------------------------------------------------

class Applicant {
  const Applicant({
    required this.userId,
    required this.name,
    required this.city,
    required this.phone,
    required this.qualification,
    required this.bio,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  factory Applicant.fromRow(Map<String, dynamic> row) {
    final profile = _map(row['profiles']);
    return Applicant(
      userId: row['user_id'] as String,
      name: (profile['full_name'] as String?) ?? '',
      city: profile['city'] as String?,
      phone: row['phone'] as String?,
      qualification: (row['qualification'] as String?) ?? '',
      bio: row['bio'] as String?,
      status: applicationStatusFromString(row['status'] as String?),
      rejectionReason: row['rejection_reason'] as String?,
      createdAt: _date(row['created_at']),
    );
  }

  final String userId;
  final String name;
  final String? city;
  final String? phone;
  final String qualification;
  final String? bio;
  final ApplicationStatus status;
  final String? rejectionReason;
  final DateTime? createdAt;

  String get displayName => name.trim().isEmpty ? 'Unnamed applicant' : name;
}

// ---------------------------------------------------------------------------
// Registrations and payments
// ---------------------------------------------------------------------------

enum RegStatus { awaitingPayment, paid, approved, rejected, cancelled }

RegStatus regStatusFrom(String? value) {
  switch (value) {
    case 'paid':
      return RegStatus.paid;
    case 'approved':
      return RegStatus.approved;
    case 'rejected':
      return RegStatus.rejected;
    case 'cancelled':
      return RegStatus.cancelled;
    default:
      return RegStatus.awaitingPayment;
  }
}

class RegistrationItem {
  const RegistrationItem({
    required this.id,
    required this.courseId,
    required this.studentId,
    required this.courseTitle,
    required this.status,
    required this.feeXaf,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.createdAt,
    required this.paidAt,
    required this.rejectionReason,
  });

  factory RegistrationItem.fromRow(Map<String, dynamic> row) =>
      RegistrationItem(
        id: row['id'] as String,
        courseId: row['course_id'] as String,
        studentId: row['student_id'] as String,
        courseTitle: (_map(row['courses'])['title'] as String?) ?? 'Course',
        status: regStatusFrom(row['status'] as String?),
        feeXaf: (row['fee_xaf'] as num?)?.toInt() ?? 0,
        fullName: (row['full_name'] as String?) ?? '',
        phone: (row['phone'] as String?) ?? '',
        city: row['city'] as String?,
        createdAt: _date(row['created_at']),
        paidAt: _date(row['paid_at']),
        rejectionReason: row['rejection_reason'] as String?,
      );

  final String id;
  final String courseId;
  final String studentId;
  final String courseTitle;
  final RegStatus status;
  final int feeXaf;
  final String fullName;
  final String phone;
  final String? city;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final String? rejectionReason;
}

enum PayState { pending, successful, failed }

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.amountXaf,
    required this.manual,
    required this.state,
    required this.operator,
    required this.payerPhone,
    required this.note,
    required this.failureReason,
    required this.studentName,
    required this.courseTitle,
    required this.createdAt,
  });

  factory PaymentItem.fromRow(Map<String, dynamic> row) {
    final reg = _map(row['registrations']);
    final status = row['status'] as String?;
    return PaymentItem(
      id: row['id'] as String,
      amountXaf: (row['amount_xaf'] as num?)?.toInt() ?? 0,
      manual: row['method'] == 'manual',
      state: status == 'successful'
          ? PayState.successful
          : status == 'failed'
              ? PayState.failed
              : PayState.pending,
      operator: row['operator'] as String?,
      payerPhone: row['payer_phone'] as String?,
      note: row['note'] as String?,
      failureReason: row['failure_reason'] as String?,
      studentName: (reg['full_name'] as String?) ?? '',
      courseTitle: (_map(reg['courses'])['title'] as String?) ?? 'Course',
      createdAt: _date(row['created_at']),
    );
  }

  final String id;
  final int amountXaf;
  final bool manual;
  final PayState state;
  final String? operator;
  final String? payerPhone;
  final String? note;
  final String? failureReason;
  final String studentName;
  final String courseTitle;
  final DateTime? createdAt;
}

class OverviewStats {
  const OverviewStats({
    required this.pendingTeachers,
    required this.toApprove,
    required this.awaitingPayment,
    required this.activeStudents,
    required this.publishedCourses,
    required this.draftCourses,
    required this.revenueXaf,
  });

  final int pendingTeachers;
  final int toApprove;
  final int awaitingPayment;
  final int activeStudents;
  final int publishedCourses;
  final int draftCourses;
  final int revenueXaf;
}

/// A student found by the cash-payment search.
class StudentRef {
  const StudentRef({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
  });

  factory StudentRef.fromRow(Map<String, dynamic> row) => StudentRef(
        id: row['id'] as String,
        name: (row['full_name'] as String?) ?? '',
        phone: row['phone'] as String?,
        city: row['city'] as String?,
      );

  final String id;
  final String name;
  final String? phone;
  final String? city;

  String get displayName => name.trim().isEmpty ? 'Unnamed student' : name;
}

/// A student's current registration for one course (for the cash dialog).
class StudentCourseState {
  const StudentCourseState({required this.courseId, required this.status});

  final String courseId;
  final RegStatus status;
}
