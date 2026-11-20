import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/greeting.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/section_card.dart';
import '../../auth/application/session_notifier.dart';
import '../../shell/page_frame.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final name = ref.watch(sessionProvider).profile?.displayName ?? 'there';
    final stats = ref.watch(adminOverviewProvider);

    return PageFrame(
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
            'Here is what needs you today.',
            style: TextStyle(color: p.ink2, fontSize: 16),
          ),
          const SizedBox(height: 22),
          AsyncBody<OverviewStats>(
            value: stats,
            onRetry: () => ref.invalidate(adminOverviewProvider),
            builder: (s) => _Content(stats: s),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats});

  final OverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final attention = <Widget>[
      if (stats.toApprove > 0)
        _AttentionTile(
          icon: Icons.how_to_reg_rounded,
          title: stats.toApprove == 1
              ? '1 paid registration to approve'
              : '${stats.toApprove} paid registrations to approve',
          action: 'Review',
          onTap: () => context.go('/admin/registrations'),
        ),
      if (stats.pendingTeachers > 0)
        _AttentionTile(
          icon: Icons.school_rounded,
          title: stats.pendingTeachers == 1
              ? '1 teacher application waiting'
              : '${stats.pendingTeachers} teacher applications waiting',
          action: 'Review',
          onTap: () => context.go('/admin/teachers'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attention.isEmpty)
          SectionCard(
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: p.accent),
                const SizedBox(width: 12),
                const Expanded(child: Text('You are all caught up.')),
              ],
            ),
          )
        else
          for (final tile in attention) ...[
            tile,
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _StatTile(
                  width: width,
                  label: 'Active students',
                  value: '${stats.activeStudents}',
                  onTap: () => context.go('/admin/registrations'),
                ),
                _StatTile(
                  width: width,
                  label: 'Published courses',
                  value: '${stats.publishedCourses}',
                  hint: stats.draftCourses == 0
                      ? null
                      : '${stats.draftCourses} in draft',
                  onTap: () => context.go('/admin/courses'),
                ),
                _StatTile(
                  width: width,
                  label: 'Awaiting payment',
                  value: '${stats.awaitingPayment}',
                  onTap: () => context.go('/admin/registrations'),
                ),
                _StatTile(
                  width: width,
                  label: 'Collected',
                  value: formatXaf(stats.revenueXaf),
                  small: true,
                  onTap: () => context.go('/admin/payments'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.icon,
    required this.title,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.warnBg, shape: BoxShape.circle),
            child: Icon(icon, color: p.warnInk, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            action,
            style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
          ),
          Icon(Icons.chevron_right_rounded, color: p.accent),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.small = false,
  });

  final double width;
  final String label;
  final String value;
  final String? hint;
  final bool small;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: width,
      child: SectionCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: p.ink2, fontSize: 14)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: small ? 22 : 32),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!, style: TextStyle(color: p.ink2, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
