import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/utils/upload_exception.dart';
import '../../../core/utils/web_files.dart';
import '../../auth/domain/models.dart';
import 'admin_models.dart';

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) Map<String, dynamic>.from(item as Map)];
}

/// All database work for the administrator. Every call is checked again by
/// the database (row level security), so a non-admin gets nothing back.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  static const _courseColumns =
      'id, title, description, category, level, duration_label, fee_xaf, '
      'status, created_at, '
      'course_teachers(teacher_id, profiles!teacher_id(full_name)), '
      'registrations(status)';

  // ----- overview -----

  Future<OverviewStats> overview() async {
    final results = await Future.wait<dynamic>([
      _client.from('teacher_applications').select('status'),
      _client.from('registrations').select('status'),
      _client.from('courses').select('status'),
      _client.from('payments').select('amount_xaf').eq('status', 'successful'),
    ]);
    final apps = _list(results[0]);
    final regs = _list(results[1]);
    final courses = _list(results[2]);
    final payments = _list(results[3]);

    int count(List<Map<String, dynamic>> rows, String value) =>
        rows.where((r) => r['status'] == value).length;

    return OverviewStats(
      pendingTeachers: count(apps, 'pending'),
      toApprove: count(regs, 'paid'),
      awaitingPayment: count(regs, 'awaiting_payment'),
      activeStudents: count(regs, 'approved'),
      publishedCourses: count(courses, 'published'),
      draftCourses: count(courses, 'draft'),
      revenueXaf: payments.fold<int>(
        0,
        (sum, row) => sum + ((row['amount_xaf'] as num?)?.toInt() ?? 0),
      ),
    );
  }

  // ----- teachers -----

  Future<List<Applicant>> applicants() async {
    final rows = await _client
        .from('teacher_applications')
        .select(
          'user_id, qualification, bio, phone, status, rejection_reason, '
          'created_at, profiles!user_id(full_name, city)',
        )
        .order('created_at', ascending: false);
    return [for (final r in _list(rows)) Applicant.fromRow(r)];
  }

  Future<void> reviewTeacher(
    String userId,
    ApplicationStatus status, {
    String? reason,
  }) async {
    await _client.rpc('review_teacher', params: {
      'p_user': userId,
      'p_status': status.name,
      'p_reason': (reason == null || reason.isEmpty) ? null : reason,
    });
  }

  Future<List<TeacherRef>> approvedTeachers() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'teacher')
        .order('full_name');
    return [
      for (final r in _list(rows))
        TeacherRef(
          id: r['id'] as String,
          name: (r['full_name'] as String?) ?? '',
        ),
    ];
  }

  // ----- courses -----

  Future<List<CourseSummary>> courses() async {
    final rows = await _client
        .from('courses')
        .select(_courseColumns)
        .order('created_at', ascending: false);
    return [for (final r in _list(rows)) CourseSummary.fromRow(r)];
  }

  Future<CourseDetail> course(String id) async {
    final row = await _client
        .from('courses')
        .select(
          '$_courseColumns, '
          'course_modules(id, title, description, position), '
          'course_materials(id, module_id, title, storage_path, mime_type, size_bytes)',
        )
        .eq('id', id)
        .single();
    return CourseDetail.fromRow(Map<String, dynamic>.from(row));
  }

  /// Creates (id == null) or updates a course. Returns the course id.
  Future<String> saveCourse({
    String? id,
    required String title,
    required String description,
    String? category,
    String? level,
    String? durationLabel,
    required int feeXaf,
    required CourseStatus status,
  }) async {
    final values = <String, dynamic>{
      'title': title,
      'description': description,
      'category': (category == null || category.isEmpty) ? null : category,
      'level': level,
      'duration_label':
          (durationLabel == null || durationLabel.isEmpty) ? null : durationLabel,
      'fee_xaf': feeXaf,
      'status': status.name,
    };
    if (id == null) {
      final created =
          await _client.from('courses').insert(values).select('id').single();
      return created['id'] as String;
    }
    await _client.from('courses').update(values).eq('id', id);
    return id;
  }

  Future<void> deleteCourse(String id) async {
    await _client.from('courses').delete().eq('id', id);
  }

  Future<void> assignTeacher(String courseId, String teacherId) async {
    await _client.from('course_teachers').insert({
      'course_id': courseId,
      'teacher_id': teacherId,
      'assigned_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> unassignTeacher(String courseId, String teacherId) async {
    await _client
        .from('course_teachers')
        .delete()
        .eq('course_id', courseId)
        .eq('teacher_id', teacherId);
  }

  // ----- notes (course modules) and their files -----

  /// Creates (noteId == null) or updates a note. Returns the note id.
  Future<String> saveNote({
    required String courseId,
    String? noteId,
    required String title,
    required String description,
    required int position,
  }) async {
    final values = <String, dynamic>{
      'title': title,
      'description': description.isEmpty ? null : description,
    };
    if (noteId != null) {
      await _client.from('course_modules').update(values).eq('id', noteId);
      return noteId;
    }
    final created = await _client
        .from('course_modules')
        .insert({...values, 'course_id': courseId, 'position': position})
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<void> deleteNote(String id) async {
    await _client.from('course_modules').delete().eq('id', id);
  }

  /// Uploads one file for a note, reporting progress (0.0 to 1.0).
  Future<void> uploadMaterial({
    required String courseId,
    required String noteId,
    required String title,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required void Function(double fraction, int sent, int total) onProgress,
  }) async {
    var session = _client.auth.currentSession;
    if (session == null) {
      throw const UploadException('Please sign in again.');
    }
    if (session.isExpired) {
      final refreshed = await _client.auth.refreshSession();
      session = refreshed.session ?? session;
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$courseId/${DateTime.now().microsecondsSinceEpoch}-$safeName';

    await uploadWithProgress(
      url: '${Env.supabaseUrl}/storage/v1/object/course-materials/$path',
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': Env.supabaseAnonKey,
        'Content-Type': mimeType,
        'x-upsert': 'false',
        'cache-control': 'max-age=3600',
      },
      bytes: bytes,
      onProgress: (sent, total) =>
          onProgress(total == 0 ? 0 : sent / total, sent, total),
    );

    try {
      await _client.from('course_materials').insert({
        'course_id': courseId,
        'module_id': noteId,
        'title': title,
        'storage_path': path,
        'mime_type': mimeType,
        'size_bytes': bytes.length,
        'created_by': _client.auth.currentUser?.id,
      });
    } catch (_) {
      await _client.storage.from('course-materials').remove([path]);
      rethrow;
    }
  }

  Future<void> deleteMaterial(CourseMaterial material) async {
    await _client.from('course_materials').delete().eq('id', material.id);
    try {
      await _client.storage
          .from('course-materials')
          .remove([material.storagePath]);
    } catch (_) {
      // The row is gone; a leftover file is harmless.
    }
  }

  Future<String> materialUrl(CourseMaterial material) {
    return _client.storage
        .from('course-materials')
        .createSignedUrl(material.storagePath, 3600);
  }

  // ----- registrations and payments -----

  Future<List<RegistrationItem>> registrations() async {
    final rows = await _client
        .from('registrations')
        .select(
          'id, course_id, student_id, status, fee_xaf, full_name, phone, city, '
          'created_at, paid_at, rejection_reason, courses(title)',
        )
        .order('created_at', ascending: false)
        .limit(500);
    return [for (final r in _list(rows)) RegistrationItem.fromRow(r)];
  }

  Future<void> reviewRegistration(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await _client.rpc('review_registration', params: {
      'p_registration': id,
      'p_approve': approve,
      'p_reason': (reason == null || reason.isEmpty) ? null : reason,
    });
  }

  /// Records cash received for a student's course. Creates the registration
  /// if needed. With [approve] the student gets access straight away.
  Future<void> recordCashPayment({
    required String studentId,
    required String courseId,
    String? note,
    bool approve = true,
  }) async {
    await _client.rpc('admin_record_cash_payment', params: {
      'p_student': studentId,
      'p_course': courseId,
      'p_note': (note == null || note.isEmpty) ? null : note,
      'p_approve': approve,
    });
  }

  Future<List<StudentRef>> searchStudents(String query) async {
    // Remove characters that have a meaning inside the filter syntax.
    final q = query.replaceAll(RegExp(r'[%,()*\\]'), ' ').trim();
    if (q.length < 2) return const [];
    final rows = await _client
        .from('profiles')
        .select('id, full_name, phone, city')
        .eq('role', 'student')
        .or('full_name.ilike.%$q%,phone.ilike.%$q%')
        .order('full_name')
        .limit(20);
    return [for (final r in _list(rows)) StudentRef.fromRow(r)];
  }

  Future<List<StudentCourseState>> studentCourseStates(String studentId) async {
    final rows = await _client
        .from('registrations')
        .select('course_id, status')
        .eq('student_id', studentId)
        .inFilter('status', ['awaiting_payment', 'paid', 'approved']);
    return [
      for (final r in _list(rows))
        StudentCourseState(
          courseId: r['course_id'] as String,
          status: regStatusFrom(r['status'] as String?),
        ),
    ];
  }

  Future<List<PaymentItem>> payments() async {
    final rows = await _client
        .from('payments')
        .select(
          'id, amount_xaf, method, status, operator, payer_phone, note, '
          'failure_reason, created_at, registrations(full_name, courses(title))',
        )
        .order('created_at', ascending: false)
        .limit(500);
    return [for (final r in _list(rows)) PaymentItem.fromRow(r)];
  }
}
