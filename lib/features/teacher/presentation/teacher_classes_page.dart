import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../classroom/data/classroom_models.dart';
import '../../shell/page_frame.dart';
import '../application/teacher_providers.dart';
import 'schedule_class_dialog.dart';
import 'teacher_widgets.dart';

class TeacherClassesPage extends ConsumerStatefulWidget {
  const TeacherClassesPage({super.key});

  @override
  ConsumerState<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

class _TeacherClassesPageState extends ConsumerState<TeacherClassesPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(teacherSessionsProvider);
    final courses = ref.watch(teacherCoursesProvider).value ?? const [];

    return PageFrame(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Classes',
            subtitle: 'Schedule a class, start it, and chat with your students.',
            action: AppButton(
              label: 'Schedule a class',
              expand: false,
              leading: const Icon(Icons.add_rounded, size: 20),
              onPressed: courses.isEmpty
                  ? null
                  : () => showScheduleClassDialog(context, courses: courses),
            ),
          ),
          AsyncBody<List<ClassSession>>(
            value: sessions,
            onRetry: () => ref.invalidate(teacherSessionsProvider),
            builder: (all) {
              final ahead = all.where((s) => s.live || s.scheduled).toList()
                ..sort((a, b) {
                  if (a.live != b.live) return a.live ? -1 : 1;
                  return a.scheduledAt.compareTo(b.scheduledAt);
                });
              final past = all.where((s) => s.finished).toList()
                ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
              final shown = _tab == 0 ? ahead : past;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipTabs(
                    labels: const ['Upcoming', 'Past'],
                    counts: [ahead.length, past.length],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 16),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.event_outlined,
                      title: _tab == 0 ? 'No upcoming class' : 'No past class yet',
                      message: _tab == 0
                          ? 'Schedule one and your students will be told.'
                          : 'Classes you finish will be listed here.',
                    )
                  else
                    for (final s in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TeacherSessionTile(session: s, courses: courses),
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
