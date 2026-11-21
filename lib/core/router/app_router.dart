import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:research_hop/features/auth/domain/session_state.dart';

import '../../features/admin/presentation/admin_courses_page.dart';
import '../../features/admin/presentation/admin_overview_page.dart';
import '../../features/admin/presentation/admin_payments_page.dart';
import '../../features/admin/presentation/admin_registrations_page.dart';
import '../../features/admin/presentation/admin_teachers_page.dart';
import '../../features/admin/presentation/course_editor_page.dart';
import '../../features/auth/application/session_notifier.dart';
import '../../features/auth/domain/models.dart';
import '../../features/auth/presentation/application_status_screens.dart';
import '../../features/auth/presentation/boot_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/teacher_apply_screen.dart';
import '../../features/classroom/presentation/classroom_page.dart';
import '../../features/home/home_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/student/presentation/payment_page.dart';
import '../../features/student/presentation/register_page.dart';
import '../../features/student/presentation/student_course_page.dart';
import '../../features/student/presentation/student_courses_page.dart';
import '../../features/student/presentation/student_home_page.dart';
import '../../features/shell/app_shell.dart';
import '../../features/teacher/presentation/teacher_classes_page.dart';
import '../../features/teacher/presentation/teacher_course_page.dart';
import '../../features/teacher/presentation/teacher_courses_page.dart';
import '../../features/teacher/presentation/teacher_home_page.dart';
import '../../features/shell/module_placeholder.dart';
import '../../features/shell/nav_destinations.dart';
import '../../features/shell/role_home_page.dart';
import 'route_guard.dart';

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

GoRoute _simple(String path, Widget Function() build) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => _fade(state, build()),
  );
}

Widget _pageFor(AppRole role, int index) {
  final item = navFor(role)[index];
  if (role == AppRole.admin) {
    switch (index) {
      case 0:
        return const AdminOverviewPage();
      case 1:
        return const AdminTeachersPage();
      case 2:
        return const AdminCoursesPage();
      case 3:
        return const AdminRegistrationsPage();
      case 4:
        return const AdminPaymentsPage();
    }
  }
  if (role == AppRole.student) {
    switch (index) {
      case 0:
        return const StudentHomePage();
      case 1:
        return const StudentCoursesPage();
      case 2:
        return const NotificationsPage();
      case 3:
        return const ProfilePage();
    }
  }
  if (role == AppRole.teacher) {
    switch (index) {
      case 0:
        return const TeacherHomePage();
      case 1:
        return const TeacherCoursesPage();
      case 2:
        return const TeacherClassesPage();
      case 3:
        return const NotificationsPage();
    }
  }
  return index == 0 ? RoleHomePage(role: role) : ModulePlaceholder(item: item);
}

GoRoute _branchRoute(String path, Widget Function(GoRouterState) build) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: build(state),
    ),
  );
}

StatefulShellRoute _shell(AppRole role) {
  final items = navFor(role);
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell, role: role),
    branches: [
      for (var i = 0; i < items.length; i++)
        StatefulShellBranch(
          routes: [
            _branchRoute(items[i].path, (_) => _pageFor(role, i)),
            // Admins and teachers reach their profile from the account menu.
            if (i == 0 && role != AppRole.student)
              _branchRoute('/${role.name}/profile', (_) => const ProfilePage()),
            // The course editor lives in the Courses branch. "new" must come
            // before ":id".
            if (role == AppRole.student && items[i].path == '/student/courses') ...[
              _branchRoute(
                '/student/courses/:id/register',
                (state) => RegisterPage(
                  key: ValueKey('reg-${state.pathParameters['id']}'),
                  courseId: state.pathParameters['id']!,
                ),
              ),
              _branchRoute(
                '/student/courses/:id',
                (state) => StudentCoursePage(
                  key: ValueKey(state.pathParameters['id']),
                  courseId: state.pathParameters['id']!,
                ),
              ),
              _branchRoute(
                '/student/classes/:id',
                (state) => ClassRoomPage(
                  key: ValueKey('room-${state.pathParameters['id']}'),
                  sessionId: state.pathParameters['id']!,
                  isTeacher: false,
                ),
              ),
              _branchRoute(
                '/student/pay/:registrationId',
                (state) => PaymentPage(
                  key: ValueKey(state.pathParameters['registrationId']),
                  registrationId: state.pathParameters['registrationId']!,
                ),
              ),
            ],
            if (role == AppRole.teacher && items[i].path == '/teacher/courses')
              _branchRoute(
                '/teacher/courses/:id',
                (state) => TeacherCoursePage(
                  key: ValueKey('tc-${state.pathParameters['id']}'),
                  courseId: state.pathParameters['id']!,
                ),
              ),
            if (role == AppRole.teacher && items[i].path == '/teacher/classes')
              _branchRoute(
                '/teacher/classes/:id',
                (state) => ClassRoomPage(
                  key: ValueKey('room-${state.pathParameters['id']}'),
                  sessionId: state.pathParameters['id']!,
                  isTeacher: true,
                ),
              ),
            if (role == AppRole.admin && items[i].path == '/admin/courses') ...[
              _branchRoute(
                '/admin/courses/new',
                (_) => const CourseEditorPage(),
              ),
              _branchRoute(
                '/admin/courses/:id',
                (state) => CourseEditorPage(
                  key: ValueKey(state.pathParameters['id']),
                  courseId: state.pathParameters['id'],
                ),
              ),
            ],
        ],
        ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/boot',
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.uri.path),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      _simple('/', () => const HomePage()),
      _simple('/boot', () => const BootScreen()),
      _simple('/login', () => const LoginScreen()),
      _simple('/register', () => const SignUpScreen(asTeacher: false)),
      _simple('/join-teacher', () => const SignUpScreen(asTeacher: true)),
      _simple('/forgot-password', () => const ForgotPasswordScreen()),
      _simple('/reset-password', () => const ResetPasswordScreen()),
      _simple('/teacher-apply', () => const TeacherApplyScreen()),
      _simple('/awaiting-approval', () => const AwaitingApprovalScreen()),
      _simple('/application-rejected', () => const ApplicationRejectedScreen()),
      _simple('/account-suspended', () => const AccountSuspendedScreen()),
      _shell(AppRole.student),
      _shell(AppRole.teacher),
      _shell(AppRole.admin),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
