import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../shell/page_frame.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

class AdminCoursesPage extends ConsumerStatefulWidget {
  const AdminCoursesPage({super.key});

  @override
  ConsumerState<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends ConsumerState<AdminCoursesPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(adminCoursesProvider);

    return PageFrame(
      maxWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Courses',
            subtitle: 'Create courses, set the fee, add notes and choose '
                'who teaches.',
            action: AppButton(
              label: 'New course',
              expand: false,
              leading: Icon(Icons.add_rounded, color: context.palette.accentInk),
              onPressed: () => context.go('/admin/courses/new'),
            ),
          ),
          AsyncBody<List<CourseSummary>>(
            value: courses,
            onRetry: () => ref.invalidate(adminCoursesProvider),
            builder: (all) {
              List<CourseSummary> by(CourseStatus s) =>
                  all.where((c) => c.status == s).toList();
              final groups = [
                all,
                by(CourseStatus.published),
                by(CourseStatus.draft),
                by(CourseStatus.archived),
              ];
              final shown = groups[_tab];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipTabs(
                    labels: const ['All', 'Published', 'Drafts', 'Archived'],
                    counts: [for (final g in groups) g.length],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 18),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: all.isEmpty ? 'No courses yet' : 'Nothing here',
                      message: all.isEmpty
                          ? 'Create your first course to get started.'
                          : null,
                      action: all.isEmpty
                          ? AppButton(
                              label: 'Create a course',
                              expand: false,
                              onPressed: () => context.go('/admin/courses/new'),
                            )
                          : null,
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 14.0;
                        final columns = constraints.maxWidth >= 720 ? 2 : 1;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final c in shown)
                              SizedBox(width: width, child: _CourseCard(course: c)),
                          ],
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final CourseSummary course;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = course;

    final ChipTone tone;
    switch (c.status) {
      case CourseStatus.published:
        tone = ChipTone.good;
      case CourseStatus.draft:
        tone = ChipTone.warn;
      case CourseStatus.archived:
        tone = ChipTone.neutral;
    }

    final meta = [
      if (c.category != null && c.category!.isNotEmpty) c.category!,
      if (c.level != null)
        c.level!.substring(0, 1).toUpperCase() + c.level!.substring(1),
      if (c.durationLabel != null && c.durationLabel!.isNotEmpty)
        c.durationLabel!,
    ].join('  ·  ');

    return SectionCard(
      onTap: () => context.go('/admin/courses/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(courseStatusLabel(c.status), tone: tone),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(color: p.ink2, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          Text(
            c.feeXaf == 0 ? 'Free' : formatXaf(c.feeXaf),
            style: TextStyle(
              color: p.accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.school_outlined, size: 18, color: p.ink2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.teachers.isEmpty
                      ? 'No teacher assigned'
                      : c.teachers
                          .map((t) => t.name.isEmpty ? 'Teacher' : t.name)
                          .join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.teachers.isEmpty ? p.warnInk : p.ink2,
                    fontSize: 14,
                    fontWeight:
                        c.teachers.isEmpty ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: p.ink2),
              const SizedBox(width: 6),
              Text(
                '${c.approvedStudents} '
                '${c.approvedStudents == 1 ? 'student' : 'students'}',
                style: TextStyle(color: p.ink2, fontSize: 14),
              ),
              if (c.waitingApproval > 0) ...[
                const SizedBox(width: 10),
                StatusChip('${c.waitingApproval} to approve', tone: ChipTone.warn),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
