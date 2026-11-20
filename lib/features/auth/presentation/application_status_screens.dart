import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/status_scaffold.dart';
import '../application/session_notifier.dart';
import '../data/auth_repository.dart';

// ---------------------------------------------------------------------------
// Waiting for the administrator
// ---------------------------------------------------------------------------

class AwaitingApprovalScreen extends ConsumerStatefulWidget {
  const AwaitingApprovalScreen({super.key});

  @override
  ConsumerState<AwaitingApprovalScreen> createState() =>
      _AwaitingApprovalScreenState();
}

class _AwaitingApprovalScreenState
    extends ConsumerState<AwaitingApprovalScreen> {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // One tiny request every 15 seconds, so this page updates by itself the
    // moment an administrator decides.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(sessionProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    await ref.read(sessionProvider.notifier).refresh();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final name = ref.watch(sessionProvider).profile?.displayName ?? 'there';

    return StatusScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeSlideIn(child: _FloatingMark()),
          const SizedBox(height: 26),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'Your application is in review',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: Text(
              'Thank you, $name. An administrator reviews every teacher '
              'application. This page updates by itself as soon as there is '
              'a decision.',
              style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          const FadeSlideIn(
            delay: Duration(milliseconds: 200),
            child: _Timeline(),
          ),
          const SizedBox(height: 30),
          AppButton(
            label: 'Check now',
            style: AppButtonStyle.outlined,
            loading: _checking,
            onPressed: _checking ? null : _checkNow,
          ),
          const SizedBox(height: 4),
          AppButton(
            label: 'Sign out',
            style: AppButtonStyle.text,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

class _FloatingMark extends StatefulWidget {
  const _FloatingMark();

  @override
  State<_FloatingMark> createState() => _FloatingMarkState();
}

class _FloatingMarkState extends State<_FloatingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, -0.08),
      ).animate(curve),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: BrandMark(size: 76),
      ),
    );
  }
}

enum _StepState { done, current, todo }

class _Timeline extends StatelessWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _TimelineRow(
          label: 'Application received',
          state: _StepState.done,
          last: false,
        ),
        _TimelineRow(
          label: 'Administrator review',
          state: _StepState.current,
          last: false,
        ),
        _TimelineRow(
          label: 'Start teaching',
          state: _StepState.todo,
          last: true,
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.state,
    required this.last,
  });

  final String label;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color dot;
    final Widget? inner;
    switch (state) {
      case _StepState.done:
        dot = p.accent;
        inner = Icon(Icons.check_rounded, size: 14, color: p.accentInk);
      case _StepState.current:
        dot = p.gold;
        inner = null;
      case _StepState.todo:
        dot = p.line;
        inner = null;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  child: inner,
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: p.line),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    state == _StepState.todo ? FontWeight.w500 : FontWeight.w600,
                color: state == _StepState.todo ? p.ink2 : p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Not approved
// ---------------------------------------------------------------------------

class ApplicationRejectedScreen extends ConsumerWidget {
  const ApplicationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final reason = ref.watch(sessionProvider).application?.rejectionReason;

    return StatusScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(
            icon: Icons.info_outline_rounded,
            background: p.warnBg,
            foreground: p.warnInk,
          ),
          const SizedBox(height: 22),
          Text(
            'Your application was not approved',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (reason != null && reason.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: Text(
                reason,
                style: TextStyle(color: p.ink, fontSize: 15, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'You can update your details and apply again.',
            style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 26),
          AppButton(
            label: 'Update and apply again',
            onPressed: () => context.go('/teacher-apply'),
          ),
          const SizedBox(height: 4),
          AppButton(
            label: 'Sign out',
            style: AppButtonStyle.text,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suspended
// ---------------------------------------------------------------------------

class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final reason = ref.watch(sessionProvider).application?.rejectionReason;

    return StatusScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(
            icon: Icons.lock_outline_rounded,
            background: p.dangerBg,
            foreground: p.danger,
          ),
          const SizedBox(height: 22),
          Text(
            'Your teacher account is suspended',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            reason != null && reason.trim().isNotEmpty
                ? reason
                : 'Please contact the administrator to find out more.',
            style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 26),
          AppButton(
            label: 'Sign out',
            style: AppButtonStyle.outlined,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground),
    );
  }
}

// ---------------------------------------------------------------------------
// Unknown address
// ---------------------------------------------------------------------------

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return StatusScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 64),
          const SizedBox(height: 22),
          Text(
            'We could not find that page',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'The address may be old or mistyped.',
            style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 26),
          AppButton(label: 'Go to the start', onPressed: () => context.go('/')),
        ],
      ),
    );
  }
}
