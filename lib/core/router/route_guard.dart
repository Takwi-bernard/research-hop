import '../../features/auth/domain/models.dart';
import '../../features/auth/domain/session_state.dart';

/// Pages anyone can open while signed out.
const Set<String> publicPaths = {
  '/',
  '/login',
  '/register',
  '/join-teacher',
  '/forgot-password',
};

/// The page a signed-in person lands on.
String homeLocationFor(SessionState session) {
  final profile = session.profile!;
  switch (profile.role) {
    case AppRole.admin:
      return '/admin';
    case AppRole.teacher:
      return '/teacher';
    case AppRole.student:
      final application = session.application;
      if (application != null) {
        switch (application.status) {
          case ApplicationStatus.pending:
            return '/awaiting-approval';
          case ApplicationStatus.rejected:
            return '/application-rejected';
          case ApplicationStatus.suspended:
            return '/account-suspended';
          case ApplicationStatus.approved:
            return '/student';
        }
      }
      return session.wantsTeacher ? '/teacher-apply' : '/student';
  }
}

/// Decides where a visitor may be. Returns null to stay, or the path to go to.
/// Kept free of Flutter code so it can be tested on its own.
String? redirectFor(SessionState session, String path) {
  switch (session.status) {
    case SessionStatus.loading:
    case SessionStatus.error:
      return path == '/boot' ? null : '/boot';

    case SessionStatus.passwordRecovery:
      return path == '/reset-password' ? null : '/reset-password';

    case SessionStatus.signedOut:
      return publicPaths.contains(path) ? null : '/';

    case SessionStatus.ready:
      final home = homeLocationFor(session);
      if (path == home || path.startsWith('$home/')) return null;
      if (path == '/teacher-apply' && session.canApplyAsTeacher) return null;
      return home;
  }
}
