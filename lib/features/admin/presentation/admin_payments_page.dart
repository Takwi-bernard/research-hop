import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../shell/page_frame.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';
import 'cash_payment_dialog.dart';

class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(adminPaymentsProvider);

    return PageFrame(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Payments',
            subtitle: 'Mobile money and cash payments, newest first.',
            action: AppButton(
              label: 'Record cash payment',
              expand: false,
              leading: Icon(Icons.payments_rounded, color: context.palette.accentInk, size: 20),
              onPressed: () async {
                final name = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const CashPaymentDialog(),
                );
                if (name != null && context.mounted) {
                  showAppSnack(context, 'Cash payment recorded for $name');
                }
              },
            ),
          ),
          AsyncBody<List<PaymentItem>>(
            value: payments,
            onRetry: () => ref.invalidate(adminPaymentsProvider),
            builder: (all) {
              final ok = all.where((x) => x.state == PayState.successful);
              final total = ok.fold<int>(0, (s, x) => s + x.amountXaf);
              final cash = ok
                  .where((x) => x.manual)
                  .fold<int>(0, (s, x) => s + x.amountXaf);

              if (all.isEmpty) {
                return const EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No payments yet',
                  message: 'Payments appear here as soon as a student pays.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Summary(label: 'Total collected', value: formatXaf(total)),
                      _Summary(
                        label: 'Mobile money',
                        value: formatXaf(total - cash),
                      ),
                      _Summary(label: 'Cash', value: formatXaf(cash)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final x in all) ...[
                    _PaymentRow(item: x),
                    const SizedBox(height: 10),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: p.ink2, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.item});

  final PaymentItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final x = item;

    final ChipTone tone;
    final String label;
    switch (x.state) {
      case PayState.successful:
        tone = ChipTone.good;
        label = 'Paid';
      case PayState.pending:
        tone = ChipTone.warn;
        label = 'Pending';
      case PayState.failed:
        tone = ChipTone.bad;
        label = 'Failed';
    }

    final how = x.manual
        ? 'Cash'
        : [
            if (x.operator != null && x.operator!.isNotEmpty) x.operator!,
            if (x.payerPhone != null && x.payerPhone!.isNotEmpty) x.payerPhone!,
          ].join(' ');
    final meta = [
      if (how.isNotEmpty) how,
      if (x.createdAt != null) formatDateTime(x.createdAt!),
    ].join('  ·  ');

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  x.studentName.isEmpty ? 'Student' : x.studentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  x.courseTitle,
                  style: TextStyle(color: p.ink2, fontSize: 14.5),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: TextStyle(color: p.ink2, fontSize: 13.5)),
                ],
                if (x.note != null && x.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    x.note!,
                    style: TextStyle(color: p.ink2, fontSize: 13.5),
                  ),
                ],
                if (x.state == PayState.failed &&
                    x.failureReason != null &&
                    x.failureReason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    x.failureReason!,
                    style: TextStyle(color: p.danger, fontSize: 13.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatXaf(x.amountXaf),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              StatusChip(label, tone: tone),
            ],
          ),
        ],
      ),
    );
  }
}
