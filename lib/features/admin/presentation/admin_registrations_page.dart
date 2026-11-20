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
import '../../shell/page_frame.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';
import 'cash_payment_dialog.dart';

class AdminRegistrationsPage extends ConsumerStatefulWidget {
  const AdminRegistrationsPage({super.key});

  @override
  ConsumerState<AdminRegistrationsPage> createState() =>
      _AdminRegistrationsPageState();
}

class _AdminRegistrationsPageState
    extends ConsumerState<AdminRegistrationsPage> {
  int _tab = 0;
  String _query = '';
  String? _busyId;

  Future<void> _run(String id, Future<void> Function() job, String done) async {
    setState(() => _busyId = id);
    try {
      await job();
      ref.invalidate(adminRegistrationsProvider);
      ref.invalidate(adminOverviewProvider);
      if (mounted) showAppSnack(context, done);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _approve(RegistrationItem r) async {
    final ok = await confirmDialog(
      context,
      title: 'Approve ${r.fullName}?',
      message: 'They will get access to ${r.courseTitle} and be notified.',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    await _run(
      r.id,
      () => ref.read(adminRepositoryProvider).reviewRegistration(
            r.id,
            approve: true,
          ),
      '${r.fullName} approved',
    );
  }

  Future<void> _reject(RegistrationItem r) async {
    final result = await showFieldsDialog(
      context,
      title: 'Reject registration',
      message: 'The student has already paid. Explain why, and settle any '
          'refund with them directly.',
      confirmLabel: 'Reject',
      fields: const [DialogField(label: 'Reason', maxLines: 3, required: true)],
    );
    if (result == null) return;
    await _run(
      r.id,
      () => ref.read(adminRepositoryProvider).reviewRegistration(
            r.id,
            approve: false,
            reason: result.first,
          ),
      'Registration rejected',
    );
  }

  Future<void> _recordCash(RegistrationItem r) async {
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CashPaymentDialog(
        student: StudentRef(
          id: r.studentId,
          name: r.fullName,
          phone: r.phone,
          city: r.city,
        ),
        courseId: r.courseId,
      ),
    );
    if (name != null && mounted) {
      showAppSnack(context, 'Cash payment recorded for $name');
    }
  }

  bool _matches(RegistrationItem r) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.fullName.toLowerCase().contains(q) ||
        r.phone.toLowerCase().contains(q) ||
        r.courseTitle.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final regs = ref.watch(adminRegistrationsProvider);

    return PageFrame(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Registrations',
            subtitle: 'Students who pay show up under "To approve". '
                'One tap lets them in.',
          ),
          AsyncBody<List<RegistrationItem>>(
            value: regs,
            onRetry: () => ref.invalidate(adminRegistrationsProvider),
            builder: (all) {
              List<RegistrationItem> by(Set<RegStatus> s) =>
                  all.where((r) => s.contains(r.status)).toList();
              final groups = [
                by({RegStatus.paid}),
                by({RegStatus.awaitingPayment}),
                by({RegStatus.approved}),
                by({RegStatus.rejected, RegStatus.cancelled}),
              ];
              final shown = groups[_tab].where(_matches).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipTabs(
                    labels: const [
                      'To approve',
                      'Awaiting payment',
                      'Approved',
                      'Closed',
                    ],
                    counts: [for (final g in groups) g.length],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, phone or course',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.how_to_reg_outlined,
                      title: _query.isNotEmpty
                          ? 'No matches'
                          : _tab == 0
                              ? 'Nothing to approve'
                              : 'Nothing here',
                      message: _tab == 0 && _query.isEmpty
                          ? 'Paid registrations will appear here by themselves.'
                          : null,
                    )
                  else
                    for (final r in shown) ...[
                      _RegistrationCard(
                        item: r,
                        busy: _busyId == r.id,
                        onApprove: () => _approve(r),
                        onReject: () => _reject(r),
                        onCash: () => _recordCash(r),
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

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCash,
  });

  final RegistrationItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCash;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = item;

    final ChipTone tone;
    final String label;
    switch (r.status) {
      case RegStatus.paid:
        tone = ChipTone.good;
        label = 'Paid';
      case RegStatus.awaitingPayment:
        tone = ChipTone.warn;
        label = 'Not paid';
      case RegStatus.approved:
        tone = ChipTone.good;
        label = 'Approved';
      case RegStatus.rejected:
        tone = ChipTone.bad;
        label = 'Rejected';
      case RegStatus.cancelled:
        tone = ChipTone.neutral;
        label = 'Cancelled';
    }

    final meta = [
      r.phone,
      if (r.city != null && r.city!.isNotEmpty) r.city!,
      if (r.createdAt != null) 'Registered ${timeAgo(r.createdAt!)}',
    ].join('  ·  ');

    final List<Widget> actions;
    if (r.status == RegStatus.paid) {
      actions = [
        AppButton(
          label: 'Approve',
          expand: false,
          loading: busy,
          onPressed: busy ? null : onApprove,
        ),
        AppButton(
          label: 'Reject',
          style: AppButtonStyle.outlined,
          expand: false,
          onPressed: busy ? null : onReject,
        ),
      ];
    } else if (r.status == RegStatus.awaitingPayment && r.feeXaf > 0) {
      actions = [
        AppButton(
          label: 'Record cash payment',
          style: AppButtonStyle.outlined,
          expand: false,
          loading: busy,
          onPressed: busy ? null : onCash,
        ),
      ];
    } else {
      actions = const [];
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusChip(label, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(meta, style: TextStyle(color: p.ink2, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.courseTitle,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatXaf(r.feeXaf),
                style: TextStyle(color: p.ink2, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (r.status == RegStatus.rejected &&
              r.rejectionReason != null &&
              r.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${r.rejectionReason}',
              style: TextStyle(color: p.danger, fontSize: 14),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}
