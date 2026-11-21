import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../classroom/data/classroom_models.dart';
import '../../shell/page_frame.dart';
import '../application/teacher_providers.dart';
import '../data/teacher_repository.dart';

class TeacherCoursesPage extends ConsumerWidget {
  const TeacherCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final courses = ref.watch(teacherCoursesProvider);
    final sessions = ref.watch(teacherSessionsProvider).value ?? const [];

    return PageFrame(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'My courses',
            subtitle: 'The courses an administrator assigned to you.',
          ),
          AsyncBody<List<TeacherCourse>>(
            value: courses,
            onRetry: () => ref.invalidate(teacherCoursesProvider),
            builder: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No course assigned yet',
                  message: 'You will get an alert as soon as one is assigned.',
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CourseCard(
                        item: item,
                        next: _nextFor(sessions, item.course.id),
                        p: p,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  ClassSession? _nextFor(List<ClassSession> all, String courseId) {
    ClassSession? best;
    for (final s in all) {
      if (s.courseId != courseId || !(s.scheduled || s.live)) continue;
      if (best == null || s.scheduledAt.isBefore(best.scheduledAt)) best = s;
    }
    return best;
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.item, required this.next, required this.p});

  final TeacherCourse item;
  final ClassSession? next;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    final c = item.course;
    final meta = [
      if (c.category != null && c.category!.isNotEmpty) c.category!,
      if (c.levelLabel.isNotEmpty) c.levelLabel,
      if (c.durationLabel != null && c.durationLabel!.isNotEmpty)
        c.durationLabel!,
    ].join('  ·  ');
    return SectionCard(
      onTap: () => context.go('/teacher/courses/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(color: p.ink2, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Fact(
                icon: Icons.groups_outlined,
                text:
                    '${item.students} ${item.students == 1 ? 'student' : 'students'}',
                p: p,
              ),
              _Fact(
                icon: Icons.event_outlined,
                text: next == null
                    ? 'No class scheduled'
                    : (next!.live
                        ? 'Live now'
                        : 'Next: ${formatDateTime(next!.scheduledAt)}'),
                p: p,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.p});

  final IconData icon;
  final String text;
  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: p.ink2),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: p.ink2, fontSize: 14.5)),
      ],
    );
  }
}
