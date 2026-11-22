import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/greeting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/section_card.dart';
import '../../auth/application/session_notifier.dart';
import '../../classroom/data/classroom_models.dart';
import '../../shell/page_frame.dart';
import '../application/teacher_providers.dart';
import '../data/teacher_repository.dart';
import 'schedule_class_dialog.dart';
import 'teacher_widgets.dart';

class TeacherHomePage extends ConsumerWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final name = ref.watch(sessionProvider).profile?.displayName ?? 'there';
    final courses = ref.watch(teacherCoursesProvider);
    final sessions = ref.watch(teacherSessionsProvider);

    return PageFrame(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            child: Text(
              '${greetingFor(DateTime.now())}, $name',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your classes and students are one tap away.',
            style: TextStyle(color: p.ink2, fontSize: 16),
          ),
          const SizedBox(height: 22),
          AsyncBody<List<TeacherCourse>>(
            value: courses,
            onRetry: () => ref.invalidate(teacherCoursesProvider),
            builder: (mine) {
              if (mine.isEmpty) {
                return const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No course assigned yet',
                  message:
                      'An administrator will assign courses to you. You will '
                      'get an alert when it happens.',
                );
              }
              return _Content(courses: mine, sessions: sessions);
            },
          ),
        ],
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.courses, required this.sessions});

  final List<TeacherCourse> courses;
  final AsyncValue<List<ClassSession>> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return AsyncBody<List<ClassSession>>(
      value: sessions,
      onRetry: () => ref.invalidate(teacherSessionsProvider),
      builder: (all) {
        final live = all.where((s) => s.live).toList();
        final next = all.where((s) => s.scheduled).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final students = courses.fold<int>(0, (sum, c) => sum + c.students);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in live)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: p.onAccentBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Live now',
                            style: TextStyle(
                              color: p.onAccentInk.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.title,
                            style: TextStyle(
                              color: p.onAccentInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            s.courseTitle,
                            style: TextStyle(
                              color: p.onAccentInk.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => context.go('/teacher/classes/${s.id}'),
                        child: const Text('Open class'),
                      ),
                    ],
                  ),
                ),
              ),
            _RequestsNotice(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Stat(label: 'Courses', value: '${courses.length}'),
                _Stat(label: 'Students', value: '$students'),
                _Stat(label: 'Classes ahead', value: '${next.length}'),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next classes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AppButton(
                  label: 'Schedule a class',
                  expand: false,
                  style: AppButtonStyle.outlined,
                  leading: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => showScheduleClassDialog(
                    context,
                    courses: courses,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (next.isEmpty)
              Text(
                'Nothing is scheduled. Plan your next class and your students '
                'will be told.',
                style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
              )
            else
              for (final s in next.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TeacherSessionTile(session: s, courses: courses),
                ),
            const SizedBox(height: 22),
            Text('Your courses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final c in courses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  onTap: () => context.go('/teacher/courses/${c.course.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.course.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${c.students} ${c.students == 1 ? 'student' : 'students'}',
                              style: TextStyle(color: p.ink2, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.ink2),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          Text(label, style: TextStyle(color: p.ink2, fontSize: 14)),
        ],
      ),
    );
  }
}

class _RequestsNotice extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final open = (ref.watch(teacherRequestsProvider).value ?? const [])
        .where((r) => r.open)
        .length;
    if (open == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.warnBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.record_voice_over_outlined, color: p.warnInk),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                open == 1
                    ? 'A student asked for a class.'
                    : '$open students asked for a class.',
                style: TextStyle(
                  color: p.warnInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/teacher/classes'),
              child: const Text('Open requests'),
            ),
          ],
        ),
      ),
    );
  }
}
