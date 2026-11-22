import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../classroom/application/classroom_providers.dart';
import '../../classroom/data/classroom_models.dart';
import '../application/student_providers.dart';

/// "Need a class?": the student asks, the teacher chooses the time.
class ClassRequestsSection extends ConsumerWidget {
  const ClassRequestsSection({super.key, required this.courseId});

  final String courseId;

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final values = await showFieldsDialog(
      context,
      title: 'Ask for a class',
      message: 'Tell your teacher what you would like to learn. '
          'Your teacher will choose the day and time and you will get an alert.',
      confirmLabel: 'Send request',
      fields: const [
        DialogField(
          label: 'What should the class cover?',
          hint: 'For example: revision of chapter 3',
          required: true,
        ),
        DialogField(
          label: 'More details (optional)',
          maxLines: 4,
        ),
      ],
    );
    if (values == null) return;
    try {
      await ref
          .read(classroomRepositoryProvider)
          .requestClass(courseId, values[0], values[1]);
      ref.invalidate(studentRequestsProvider(courseId));
      if (context.mounted) {
        showAppSnack(context, 'Request sent. Your teacher will choose a time.');
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    ClassRequest request,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this request?',
      message: request.topic,
      confirmLabel: 'Cancel request',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(classroomRepositoryProvider).cancelRequest(request.id);
      ref.invalidate(studentRequestsProvider(courseId));
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final items = (ref.watch(studentRequestsProvider(courseId)).value ??
            const <ClassRequest>[])
        .where((r) => r.status != RequestStatus.cancelled)
        .take(6)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Need a class?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          SectionCard(
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    'Ask for a class on a topic you find hard. Your teacher '
                    'decides when it takes place.',
                    style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
                  ),
                ),
                AppButton(
                  label: 'Ask for a class',
                  expand: false,
                  leading: const Icon(Icons.record_voice_over_outlined, size: 18),
                  onPressed: () => _ask(context, ref),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.topic,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          switch (r.status) {
                            RequestStatus.open =>
                              const StatusChip('Waiting', tone: ChipTone.warn),
                            RequestStatus.scheduled =>
                              const StatusChip('Scheduled', tone: ChipTone.good),
                            _ => const StatusChip('Not now'),
                          },
                        ],
                      ),
                      Text(
                        timeAgo(r.createdAt),
                        style: TextStyle(color: p.ink2, fontSize: 13),
                      ),
                      if (r.status == RequestStatus.declined &&
                          r.teacherReply.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          r.teacherReply,
                          style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.4),
                        ),
                      ],
                      if (r.open)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _cancel(context, ref, r),
                            child: const Text('Cancel request'),
                          ),
                        ),
                      if (r.status == RequestStatus.scheduled && r.sessionId != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                context.go('/student/classes/${r.sessionId}'),
                            child: const Text('View the class'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
