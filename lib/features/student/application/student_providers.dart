import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';
import '../../classroom/application/classroom_providers.dart';
import '../../classroom/data/classroom_models.dart';
import '../data/student_models.dart';
import '../data/student_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => StudentRepository(ref.watch(supabaseClientProvider)),
);

/// Ticks when something the student sees changes (registration status,
/// payment, courses, classes, notes), so pages refresh by themselves.
final studentLiveProvider = StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var ticks = 0;

  final channel = client.channel('student-live');
  void bump(PostgresChangePayload payload) {
    if (!controller.isClosed) controller.add(++ticks);
  }

  for (final table in const [
    'registrations',
    'payments',
    'courses',
    'class_sessions',
    'course_modules',
    'course_materials',
    'course_announcements',
    'class_requests',
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

final catalogProvider = FutureProvider.autoDispose<List<CatalogCourse>>((ref) {
  ref.watch(studentLiveProvider);
  return ref.watch(studentRepositoryProvider).catalog();
});

final myRegistrationsProvider =
    FutureProvider.autoDispose<List<MyRegistration>>((ref) {
  ref.watch(studentLiveProvider);
  return ref.watch(studentRepositoryProvider).myRegistrations();
});

final upcomingClassesProvider =
    FutureProvider.autoDispose<List<ClassItem>>((ref) {
  ref.watch(studentLiveProvider);
  return ref.watch(studentRepositoryProvider).upcomingClasses();
});

final courseContentProvider =
    FutureProvider.autoDispose.family<CourseContent, String>((ref, courseId) {
  ref.watch(studentLiveProvider);
  return ref.watch(studentRepositoryProvider).content(courseId);
});

final courseClassesProvider = FutureProvider.autoDispose
    .family<List<ClassSession>, String>((ref, courseId) {
  ref.watch(studentLiveProvider);
  return ref.watch(studentRepositoryProvider).courseClasses(courseId);
});

final studentAnnouncementsProvider = FutureProvider.autoDispose
    .family<List<Announcement>, String>((ref, courseId) {
  ref.watch(studentLiveProvider);
  return ref.watch(classroomRepositoryProvider).announcements(courseId);
});

final studentRequestsProvider = FutureProvider.autoDispose
    .family<List<ClassRequest>, String>((ref, courseId) {
  ref.watch(studentLiveProvider);
  return ref.watch(classroomRepositoryProvider).requests(courseId: courseId);
});
