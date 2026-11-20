import 'package:flutter_test/flutter_test.dart';
import 'package:research_hop/core/router/route_guard.dart';
import 'package:research_hop/features/auth/domain/models.dart';
import 'package:research_hop/features/auth/domain/session_state.dart';

Profile _profile(AppRole role) =>
    Profile(id: 'u1', role: role, fullName: 'Test User');

SessionState _ready(
  AppRole role, {
  ApplicationStatus? application,
  bool wantsTeacher = false,
}) {
  return SessionState.ready(
    profile: _profile(role),
    application:
        application == null ? null : TeacherApplication(status: application),
    wantsTeacher: wantsTeacher,
  );
}

void main() {
  group('redirectFor', () {
    test('loading goes to boot', () {
      expect(redirectFor(const SessionState.loading(), '/login'), '/boot');
      expect(redirectFor(const SessionState.loading(), '/boot'), isNull);
    });

    test('signed out may only see public pages', () {
      const s = SessionState.signedOut();
      expect(redirectFor(s, '/'), isNull);
      expect(redirectFor(s, '/login'), isNull);
      expect(redirectFor(s, '/register'), isNull);
      expect(redirectFor(s, '/student'), '/');
      expect(redirectFor(s, '/admin'), '/');
      expect(redirectFor(s, '/admin/courses/new'), '/');
    });

    test('password recovery is locked to the reset page', () {
      const s = SessionState.passwordRecovery();
      expect(redirectFor(s, '/login'), '/reset-password');
      expect(redirectFor(s, '/reset-password'), isNull);
    });

    test('students cannot open teacher or admin areas', () {
      final s = _ready(AppRole.student);
      expect(redirectFor(s, '/student'), isNull);
      expect(redirectFor(s, '/student/courses'), isNull);
      expect(redirectFor(s, '/admin'), '/student');
      expect(redirectFor(s, '/teacher'), '/student');
      expect(redirectFor(s, '/login'), '/student');
      expect(redirectFor(s, '/'), '/student');
    });

    test('admin may open nested admin pages', () {
      final s = _ready(AppRole.admin);
      expect(redirectFor(s, '/admin/courses/new'), isNull);
      expect(redirectFor(s, '/admin/courses/abc'), isNull);
    });

    test('teachers and admins land in their own area', () {
      expect(homeLocationFor(_ready(AppRole.teacher)), '/teacher');
      expect(homeLocationFor(_ready(AppRole.admin)), '/admin');
      expect(redirectFor(_ready(AppRole.admin), '/teacher'), '/admin');
    });
  });

  group('teacher applications', () {
    test('pending, rejected and suspended have their own pages', () {
      expect(
        homeLocationFor(_ready(AppRole.student, application: ApplicationStatus.pending)),
        '/awaiting-approval',
      );
      expect(
        homeLocationFor(_ready(AppRole.student, application: ApplicationStatus.rejected)),
        '/application-rejected',
      );
      expect(
        homeLocationFor(_ready(AppRole.student, application: ApplicationStatus.suspended)),
        '/account-suspended',
      );
    });

    test('a student who chose to teach is sent to the form', () {
      final s = _ready(AppRole.student, wantsTeacher: true);
      expect(homeLocationFor(s), '/teacher-apply');
    });

    test('a rejected applicant may reopen the form', () {
      final s = _ready(AppRole.student, application: ApplicationStatus.rejected);
      expect(s.canApplyAsTeacher, isTrue);
      expect(redirectFor(s, '/teacher-apply'), isNull);
    });

    test('a pending applicant cannot open the form again', () {
      final s = _ready(AppRole.student, application: ApplicationStatus.pending);
      expect(s.canApplyAsTeacher, isFalse);
      expect(redirectFor(s, '/teacher-apply'), '/awaiting-approval');
    });
  });
}
