import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../classroom/data/classroom_models.dart';
import '../application/teacher_providers.dart';
import '../data/teacher_repository.dart';
import 'schedule_class_dialog.dart';

/// One class in a list. Tap opens the class room; scheduled classes can be
/// edited or cancelled from the menu.
class TeacherSessionTile extends ConsumerWidget {
  const TeacherSessionTile({
    super.key,
    required this.session,
    required this.courses,
    this.showCourse = true,
  });

  final ClassSession session;
  final List<TeacherCourse> courses;
  final bool showCourse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final (label, tone) = switch (session.status) {
      ClassStatus.live => ('Live now', ChipTone.bad),
      ClassStatus.scheduled => ('Scheduled', ChipTone.warn),
      ClassStatus.ended => ('Ended', ChipTone.neutral),
      ClassStatus.cancelled => ('Cancelled', ChipTone.neutral),
    };

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      onTap: () => context.go('/teacher/classes/${session.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  showCourse
                      ? '${session.courseTitle}  ·  ${formatDateTime(session.scheduledAt)}'
                      : formatDateTime(session.scheduledAt),
                  style: TextStyle(color: p.ink2, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label, tone: tone),
          if (session.scheduled)
            PopupMenuButton<String>(
              tooltip: 'Class options',
              icon: Icon(Icons.more_vert_rounded, color: p.ink2),
              onSelected: (value) async {
                if (value == 'edit') {
                  final saved = await showScheduleClassDialog(
                    context,
                    courses: courses,
                    existing: session,
                  );
                  if (saved && context.mounted) showAppSnack(context, 'Class updated');
                } else if (value == 'cancel') {
                  final ok = await confirmDialog(
                    context,
                    title: 'Cancel this class?',
                    message: 'Enrolled students will be told it was cancelled.',
                    confirmLabel: 'Cancel class',
                    danger: true,
                  );
                  if (!ok) return;
                  try {
                    await ref.read(teacherRepositoryProvider).cancelClass(session.id);
                    ref.invalidate(teacherSessionsProvider);
                    if (context.mounted) showAppSnack(context, 'Class cancelled');
                  } catch (error) {
                    if (context.mounted) {
                      showAppSnack(context, friendlyError(error), error: true);
                    }
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel class')),
              ],
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}
