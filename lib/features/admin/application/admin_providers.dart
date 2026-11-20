import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

/// Ticks whenever one of the admin's tables changes, so lists refresh by
/// themselves. Needs the tables added to the Realtime publication (see
/// supabase/002_admin_realtime.sql).
final adminLiveProvider = StreamProvider.autoDispose<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>();
  var ticks = 0;

  final channel = client.channel('admin-live');
  void bump(PostgresChangePayload payload) {
    if (!controller.isClosed) controller.add(++ticks);
  }

  for (final table in const [
    'registrations',
    'teacher_applications',
    'payments',
    'courses',
    'course_teachers',
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

final adminOverviewProvider =
    FutureProvider.autoDispose<OverviewStats>((ref) {
  ref.watch(adminLiveProvider);
  return ref.watch(adminRepositoryProvider).overview();
});

final adminApplicantsProvider =
    FutureProvider.autoDispose<List<Applicant>>((ref) {
  ref.watch(adminLiveProvider);
  return ref.watch(adminRepositoryProvider).applicants();
});

final adminCoursesProvider =
    FutureProvider.autoDispose<List<CourseSummary>>((ref) {
  ref.watch(adminLiveProvider);
  return ref.watch(adminRepositoryProvider).courses();
});

final adminCourseProvider =
    FutureProvider.autoDispose.family<CourseDetail, String>((ref, id) {
  ref.watch(adminLiveProvider);
  return ref.watch(adminRepositoryProvider).course(id);
});

final adminRegistrationsProvider =
    FutureProvider.autoDispose<List<RegistrationItem>>((ref) {
  ref.watch(adminLiveProvider);
  return ref.watch(adminRepositoryProvider).registrations();
});

final adminPaymentsProvider =
    FutureProvider.autoDispose<List<PaymentItem>>((ref) {
  ref.watch(adminLiveProvider);
  return ref.watch(adminRepositoryProvider).payments();
});

final approvedTeachersProvider =
    FutureProvider.autoDispose<List<TeacherRef>>((ref) {
  return ref.watch(adminRepositoryProvider).approvedTeachers();
});
