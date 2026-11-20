import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/status_scaffold.dart';
import '../application/session_notifier.dart';
import '../data/auth_repository.dart';
import '../domain/session_state.dart';

/// The first screen: a quiet pulse while we check who is signed in.
/// If the connection fails it explains and offers to try again.
class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final p = context.palette;

    if (session.status == SessionStatus.error) {
      return StatusScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: p.warnBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: p.warnInk),
            ),
            const SizedBox(height: 22),
            Text(
              'We could not load your account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              session.message ?? 'Please check your connection.',
              style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 26),
            AppButton(
              label: 'Try again',
              onPressed: () => ref.read(sessionProvider.notifier).retry(),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Sign out',
              style: AppButtonStyle.text,
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingMark(),
            const SizedBox(height: 20),
            Text(
              'Research Hop',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Learn, one hop at a time.',
              style: TextStyle(color: p.ink2, fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingMark extends StatefulWidget {
  const _PulsingMark();

  @override
  State<_PulsingMark> createState() => _PulsingMarkState();
}

class _PulsingMarkState extends State<_PulsingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_curve),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.04).animate(_curve),
        child: const BrandMark(size: 84),
      ),
    );
  }
}
