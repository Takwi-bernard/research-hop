import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_exception.dart';
import '../../classroom/data/classroom_models.dart';
import '../../student/data/student_models.dart';

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) Map<String, dynamic>.from(item as Map)];
}

class TeacherCourse {
  const TeacherCourse({required this.course, required this.students});

  final CatalogCourse course;
  final int students;
}

class TeacherRepository {
  TeacherRepository(this._client);

  final SupabaseClient _client;

  String get myId => _client.auth.currentUser?.id ?? '';

  /// Only the courses an administrator assigned to this teacher, with how
  /// many students are enrolled (a count, never names).
  Future<List<TeacherCourse>> myCourses() async {
    final rows = await _client
        .from('course_teachers')
        .select(
          'courses(id, title, description, category, level, duration_label, fee_xaf)',
        )
        .eq('teacher_id', myId);
    final courses = <CatalogCourse>[];
    for (final row in _list(rows)) {
      final raw = row['courses'];
      if (raw is Map) {
        courses.add(CatalogCourse.fromRow(Map<String, dynamic>.from(raw)));
      }
    }
    courses.sort((a, b) => a.title.compareTo(b.title));

    final counts = await Future.wait<int>([
      for (final c in courses) _studentCount(c.id),
    ]);
    return [
      for (var i = 0; i < courses.length; i++)
        TeacherCourse(course: courses[i], students: counts[i]),
    ];
  }

  Future<int> _studentCount(String courseId) async {
    try {
      final value = await _client
          .rpc('course_student_count', params: {'p_course': courseId});
      return (value as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static const _sessionColumns =
      'id, course_id, teacher_id, title, description, scheduled_at, status, '
      'chat_mode, students_can_send_media, started_at, ended_at, courses(title)';

  Future<List<ClassSession>> sessions() async {
    final rows = await _client
        .from('class_sessions')
        .select(_sessionColumns)
        .order('scheduled_at', ascending: false)
        .limit(150);
    return [for (final r in _list(rows)) ClassSession.fromRow(r)];
  }

  Future<void> scheduleClass({
    required String courseId,
    required String title,
    required String description,
    required DateTime when,
  }) async {
    if (when.isBefore(DateTime.now().subtract(const Duration(minutes: 4)))) {
      throw const AppException('Please choose a time that is not in the past.');
    }
    await _client.from('class_sessions').insert({
      'course_id': courseId,
      'teacher_id': myId,
      'title': title,
      'description': description.isEmpty ? null : description,
      'scheduled_at': when.toUtc().toIso8601String(),
    });
  }

  Future<void> updateClass({
    required String id,
    required String title,
    required String description,
    required DateTime when,
  }) async {
    final updated = await _client
        .from('class_sessions')
        .update({
          'title': title,
          'description': description.isEmpty ? null : description,
          'scheduled_at': when.toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select('id');
    if (updated.isEmpty) {
      throw const AppException('This class can no longer be changed.');
    }
  }

  Future<void> cancelClass(String id) =>
      _client.rpc('cancel_session', params: {'p_session': id});
}
