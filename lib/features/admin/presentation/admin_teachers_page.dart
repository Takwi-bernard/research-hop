import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/domain/models.dart';
import '../../shell/page_frame.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

class AdminTeachersPage extends ConsumerStatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  ConsumerState<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends ConsumerState<AdminTeachersPage> {
  int _tab = 0;
  String? _busyId;

  Future<void> _review(
    Applicant a,
    ApplicationStatus status, {
    String? reason,
    required String done,
  }) async {
    setState(() => _busyId = a.userId);
    try {
      await ref
          .read(adminRepositoryProvider)
          .reviewTeacher(a.userId, status, reason: reason);
      ref.invalidate(adminApplicantsProvider);
      ref.invalidate(adminOverviewProvider);
      if (mounted) showAppSnack(context, done);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _approve(Applicant a) => _review(
        a,
        ApplicationStatus.approved,
        done: '${a.displayName} is now a teacher',
      );

  Future<void> _decline(Applicant a) async {
    final result = await showFieldsDialog(
      context,
      title: 'Decline application',
      message: 'The applicant will be told. A short reason helps them.',
      confirmLabel: 'Decline',
      fields: const [
        DialogField(label: 'Reason (optional)', maxLines: 3),
      ],
    );
    if (result == null) return;
    await _review(
      a,
      ApplicationStatus.rejected,
      reason: result.first,
      done: 'Application declined',
    );
  }

  Future<void> _suspend(Applicant a) async {
    final result = await showFieldsDialog(
      context,
      title: 'Suspend ${a.displayName}',
      message: 'They lose teacher access until you reinstate them.',
      confirmLabel: 'Suspend',
      fields: const [
        DialogField(label: 'Reason (optional)', maxLines: 3),
      ],
    );
    if (result == null) return;
    await _review(
      a,
      ApplicationStatus.suspended,
      reason: result.first,
      done: '${a.displayName} is suspended',
    );
  }

  @override
  Widget build(BuildContext context) {
    final applicants = ref.watch(adminApplicantsProvider);
    final courses = ref.watch(adminCoursesProvider).value ?? const [];

    return PageFrame(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Teachers',
            subtitle: 'Approve people who want to teach, then assign them '
                'to courses.',
          ),
          AsyncBody<List<Applicant>>(
            value: applicants,
            onRetry: () => ref.invalidate(adminApplicantsProvider),
            builder: (all) {
              final pending =
                  all.where((a) => a.status == ApplicationStatus.pending).toList();
              final active =
                  all.where((a) => a.status == ApplicationStatus.approved).toList();
              final other = all
                  .where((a) =>
                      a.status == ApplicationStatus.rejected ||
                      a.status == ApplicationStatus.suspended)
                  .toList();
              final lists = [pending, active, other];
              final shown = lists[_tab];

              String coursesOf(String teacherId) {
                final titles = [
                  for (final c in courses)
                    if (c.teachers.any((t) => t.id == teacherId)) c.title,
                ];
                return titles.isEmpty ? 'No courses yet' : titles.join(', ');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipTabs(
                    labels: const ['Waiting', 'Teachers', 'Declined or suspended'],
                    counts: [pending.length, active.length, other.length],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 18),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.school_outlined,
                      title: _tab == 0
                          ? 'No applications waiting'
                          : _tab == 1
                              ? 'No teachers yet'
                              : 'Nobody here',
                      message: _tab == 0
                          ? 'New teacher applications will appear here at once.'
                          : null,
                    )
                  else
                    for (final a in shown) ...[
                      _ApplicantCard(
                        applicant: a,
                        busy: _busyId == a.userId,
                        coursesLine:
                            a.status == ApplicationStatus.approved
                                ? coursesOf(a.userId)
                                : null,
                        onApprove: () => _approve(a),
                        onDecline: () => _decline(a),
                        onSuspend: () => _suspend(a),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.applicant,
    required this.busy,
    required this.coursesLine,
    required this.onApprove,
    required this.onDecline,
    required this.onSuspend,
  });

  final Applicant applicant;
  final bool busy;
  final String? coursesLine;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = applicant;
    final details = [
      if (a.phone != null && a.phone!.isNotEmpty) a.phone!,
      if (a.city != null && a.city!.isNotEmpty) a.city!,
      if (a.createdAt != null) 'Applied ${timeAgo(a.createdAt!)}',
    ].join('  ·  ');

    final ChipTone tone;
    final String label;
    switch (a.status) {
      case ApplicationStatus.pending:
        tone = ChipTone.warn;
        label = 'Waiting';
      case ApplicationStatus.approved:
        tone = ChipTone.good;
        label = 'Teacher';
      case ApplicationStatus.rejected:
        tone = ChipTone.bad;
        label = 'Declined';
      case ApplicationStatus.suspended:
        tone = ChipTone.bad;
        label = 'Suspended';
    }

    final List<Widget> actions;
    switch (a.status) {
      case ApplicationStatus.pending:
        actions = [
          AppButton(
            label: 'Approve',
            expand: false,
            loading: busy,
            onPressed: busy ? null : onApprove,
          ),
          AppButton(
            label: 'Decline',
            style: AppButtonStyle.outlined,
            expand: false,
            onPressed: busy ? null : onDecline,
          ),
        ];
      case ApplicationStatus.approved:
        actions = [
          AppButton(
            label: 'Suspend',
            style: AppButtonStyle.outlined,
            expand: false,
            loading: busy,
            onPressed: busy ? null : onSuspend,
          ),
        ];
      case ApplicationStatus.rejected:
        actions = [
          AppButton(
            label: 'Approve instead',
            expand: false,
            loading: busy,
            onPressed: busy ? null : onApprove,
          ),
        ];
      case ApplicationStatus.suspended:
        actions = [
          AppButton(
            label: 'Reinstate',
            expand: false,
            loading: busy,
            onPressed: busy ? null : onApprove,
          ),
        ];
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusChip(label, tone: tone),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details, style: TextStyle(color: p.ink2, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          Text(
            a.qualification,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
          if (a.bio != null && a.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              a.bio!,
              style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.45),
            ),
          ],
          if (coursesLine != null) ...[
            const SizedBox(height: 10),
            Text(
              'Courses: $coursesLine',
              style: TextStyle(color: p.ink2, fontSize: 14),
            ),
          ],
          if (a.rejectionReason != null && a.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reason given: ${a.rejectionReason}',
              style: TextStyle(color: p.danger, fontSize: 14),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}
