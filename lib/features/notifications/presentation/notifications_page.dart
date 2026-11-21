import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../auth/application/session_notifier.dart';
import '../../auth/domain/models.dart';
import '../../shell/page_frame.dart';
import '../data/notifications_data.dart';

IconData _iconFor(String type) {
  switch (type) {
    case 'registration_approved':
      return Icons.celebration_outlined;
    case 'registration_rejected':
      return Icons.highlight_off_rounded;
    case 'payment_received':
    case 'registration_paid':
      return Icons.payments_outlined;
    case 'session_scheduled':
    case 'session_reminder':
    case 'session_live':
    case 'session_ended':
    case 'session_cancelled':
      return Icons.event_available_outlined;
    case 'announcement':
      return Icons.campaign_outlined;
    case 'teacher_approved':
    case 'teacher_rejected':
    case 'teacher_suspended':
    case 'teacher_applied':
      return Icons.school_outlined;
    default:
      return Icons.notifications_none_rounded;
  }
}

/// Alerts for students and teachers. New ones appear by themselves.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    try {
      if (item.unread) {
        await ref.read(notificationRepositoryProvider).markRead(item.id);
        ref.invalidate(notificationsProvider);
      }
    } catch (_) {
      // Opening still works if marking as read fails.
    }
    final role = ref.read(sessionProvider).profile?.role;
    if (!context.mounted) return;
    if (role == AppRole.student) {
      if (item.sessionId != null && item.type != 'session_cancelled') {
        context.go('/student/classes/${item.sessionId}');
      } else if (item.courseId != null) {
        context.go('/student/courses/${item.courseId}');
      }
    } else if (role == AppRole.teacher) {
      if (item.sessionId != null && item.type != 'session_cancelled') {
        context.go('/teacher/classes/${item.sessionId}');
      } else if (item.courseId != null) {
        context.go('/teacher/courses/${item.courseId}');
      }
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return PageFrame(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Alerts',
            subtitle: unread == 0 ? 'You are up to date.' : '$unread unread',
            action: unread == 0
                ? null
                : AppButton(
                    label: 'Mark all as read',
                    style: AppButtonStyle.outlined,
                    expand: false,
                    onPressed: () => _markAll(context, ref),
                  ),
          ),
          AsyncBody<List<AppNotification>>(
            value: async,
            onRetry: () => ref.invalidate(notificationsProvider),
            builder: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No alerts yet',
                  message: 'Class reminders, payment updates and '
                      'announcements will appear here.',
                );
              }
              return Column(
                children: [
                  for (final n in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionCard(
                        onTap: () => _open(context, ref, n),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: n.unread ? p.softBg : p.surface2,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconFor(n.type),
                                size: 21,
                                color: n.unread ? p.softInk : p.ink2,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: n.unread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  if (n.body != null && n.body!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      n.body!,
                                      style: TextStyle(
                                        color: p.ink2,
                                        fontSize: 14.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    timeAgo(n.createdAt),
                                    style: TextStyle(color: p.ink2, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            if (n.unread)
                              Container(
                                margin: const EdgeInsets.only(top: 6, left: 8),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
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
