import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/greeting.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../auth/application/session_notifier.dart';
import '../auth/domain/models.dart';
import 'nav_destinations.dart';
import 'page_frame.dart';

/// First page of each role: a greeting plus a placeholder card.
class RoleHomePage extends ConsumerWidget {
  const RoleHomePage({super.key, required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final name = ref.watch(sessionProvider).profile?.displayName ?? 'there';
    final item = navFor(role).first;
    final subtitle = switch (role) {
      AppRole.student => 'Ready to learn something today?',
      AppRole.teacher => 'Your classes and students are one tap away.',
      AppRole.admin => 'Here is how Research Hop is doing.',
    };

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
          const SizedBox(height: 6),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Text(subtitle, style: TextStyle(color: p.ink2, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.line),
              ),
              child: Text(
                item.comingWith,
                style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
