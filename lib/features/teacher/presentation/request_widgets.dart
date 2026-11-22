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
import '../../classroom/application/classroom_providers.dart';
import '../../classroom/data/classroom_models.dart';
import '../application/teacher_providers.dart';
import '../data/teacher_repository.dart';
import 'schedule_class_dialog.dart';

/// One student request. Open ones have "Choose a time" and "Not now".
/// The teacher always decides the time.
class RequestCard extends ConsumerWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.courses,
    this.showCourse = true,
  });

  final ClassRequest request;
  final List<TeacherCourse> courses;
  final bool showCourse;

  Future<void> _schedule(BuildContext context) async {
    final saved = await showScheduleClassDialog(
      context,
      courses: courses,
      request: request,
    );
    if (saved && context.mounted) {
      showAppSnack(context, 'Class scheduled. The student has been told.');
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final values = await showFieldsDialog(
      context,
      title: 'Not now',
      message: 'The student will be told. You can add a short reason.',
      confirmLabel: 'Send',
      fields: const [
        DialogField(
          label: 'Message to the student (optional)',
          hint: 'For example: this topic is covered next week',
          maxLines: 3,
        ),
      ],
    );
    if (values == null) return;
    try {
      await ref
          .read(classroomRepositoryProvider)
          .declineRequest(request.id, values[0]);
      ref.invalidate(teacherRequestsProvider);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final (label, tone) = switch (request.status) {
      RequestStatus.open => ('New', ChipTone.warn),
      RequestStatus.scheduled => ('Scheduled', ChipTone.good),
      RequestStatus.declined => ('Not now', ChipTone.neutral),
      RequestStatus.cancelled => ('Cancelled', ChipTone.neutral),
    };

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.topic,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label, tone: tone),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            showCourse
                ? '${request.studentLabel}  ·  ${request.courseTitle}  ·  ${timeAgo(request.createdAt)}'
                : '${request.studentLabel}  ·  ${timeAgo(request.createdAt)}',
            style: TextStyle(color: p.ink2, fontSize: 13.5),
          ),
          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.note, style: const TextStyle(fontSize: 15, height: 1.45)),
          ],
          if (request.open) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _schedule(context),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: const Text('Choose a time'),
                ),
                TextButton(
                  onPressed: () => _decline(context, ref),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ] else if (request.status == RequestStatus.scheduled &&
              request.sessionId != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/teacher/classes/${request.sessionId}'),
              child: const Text('Open the class'),
            ),
          ],
        ],
      ),
    );
  }
}
