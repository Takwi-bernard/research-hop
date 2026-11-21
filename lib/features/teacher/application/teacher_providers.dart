import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';
import '../../classroom/application/classroom_providers.dart';
import '../../classroom/data/classroom_models.dart';
import '../data/teacher_repository.dart';

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => TeacherRepository(ref.watch(supabaseClientProvider)),
);

/// Ticks when classes, assignments, announcements or notes change, so the
/// teacher's pages refresh by themselves.
final teacherLiveProvider = StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var ticks = 0;

  final channel = client.channel('teacher-live');
  void bump(PostgresChangePayload payload) {
    if (!controller.isClosed) controller.add(++ticks);
  }

  for (final table in const [
    'class_sessions',
    'course_teachers',
    'course_announcements',
    'course_modules',
    'course_materials',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: bump,
    );
  }
  channel.subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

final teacherCoursesProvider =
    FutureProvider.autoDispose<List<TeacherCourse>>((ref) {
  ref.watch(teacherLiveProvider);
  return ref.watch(teacherRepositoryProvider).myCourses();
});

final teacherSessionsProvider =
    FutureProvider.autoDispose<List<ClassSession>>((ref) {
  ref.watch(teacherLiveProvider);
  return ref.watch(teacherRepositoryProvider).sessions();
});

final courseAnnouncementsProvider = FutureProvider.autoDispose
    .family<List<Announcement>, String>((ref, courseId) {
  ref.watch(teacherLiveProvider);
  return ref.watch(classroomRepositoryProvider).announcements(courseId);
});
