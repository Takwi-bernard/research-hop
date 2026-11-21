import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/greeting.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../admin/data/admin_models.dart';
import '../../auth/application/session_notifier.dart';
import '../../shell/page_frame.dart';
import '../application/student_providers.dart';
import '../data/student_models.dart';

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final name = ref.watch(sessionProvider).profile?.displayName ?? 'there';
    final regs = ref.watch(myRegistrationsProvider);
    final classes = ref.watch(upcomingClassesProvider);

    return PageFrame(
      maxWidth: 900,
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
            'Ready to learn something today?',
            style: TextStyle(color: p.ink2, fontSize: 16),
          ),
          const SizedBox(height: 22),
          AsyncBody<List<MyRegistration>>(
            value: regs,
            onRetry: () => ref.invalidate(myRegistrationsProvider),
            builder: (all) {
              final toPay =
                  all.where((r) => r.status == RegStatus.awaitingPayment).toList();
              final waiting = all.where((r) => r.status == RegStatus.paid).toList();
              final enrolled =
                  all.where((r) => r.status == RegStatus.approved).toList();

              if (all.isEmpty) {
                return EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Find your first course',
                  message: 'Browse the courses, register and pay once. '
                      'Your classes will show up here.',
                  action: AppButton(
                    label: 'Browse courses',
                    expand: false,
                    onPressed: () => context.go('/student/courses'),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in toPay) ...[
                    _ActionCard(
                      title: 'Finish paying for ${r.courseTitle}',
                      body: '${formatXaf(r.feeXaf)} with MTN or Orange Money.',
                      button: 'Pay now',
                      onTap: () => context.go('/student/pay/${r.id}'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final r in waiting) ...[
                    SectionCard(
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: p.warnInk),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment received for ${r.courseTitle}. An '
                              'administrator will confirm your place soon.',
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  Text('My courses',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (enrolled.isEmpty)
                    Text(
                      'Courses appear here once your registration is approved.',
                      style: TextStyle(color: p.ink2, fontSize: 15),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final columns = constraints.maxWidth >= 640 ? 2 : 1;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final r in enrolled)
                              SizedBox(
                                width: width,
                                child: SectionCard(
                                  onTap: () =>
                                      context.go('/student/courses/${r.courseId}'),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: p.softBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.menu_book_rounded,
                                            color: p.softInk, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          r.courseTitle,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: p.ink2),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Upcoming classes',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AsyncBody<List<ClassItem>>(
            value: classes,
            onRetry: () => ref.invalidate(upcomingClassesProvider),
            builder: (items) {
              if (items.isEmpty) {
                return Text(
                  'No class is scheduled yet. You will get an alert when '
                  'your teacher plans one.',
                  style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
                );
              }
              return Column(
                children: [
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionCard(
                        onTap: () => context.go('/student/classes/${c.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c.courseTitle}  ·  '
                                    '${formatDateTime(c.scheduledAt)}',
                                    style: TextStyle(color: p.ink2, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            if (c.live)
                              const StatusChip('Join now', tone: ChipTone.bad),
                          ],
                        ),
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
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.body,
    required this.button,
    required this.onTap,
  });

  final String title;
  final String body;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.warnBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.warnInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: p.warnInk)),
              ],
            ),
          ),
          AppButton(label: button, expand: false, onPressed: onTap),
        ],
      ),
    );
  }
}
