import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/theme_mode_switcher.dart';

/// The public front door of Research Hop. Anyone can read it; signing in
/// sends each person to the right place for their role.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: const [
                    _Hero(),
                    _Features(),
                    _Steps(),
                    _TeacherBand(),
                    _Footer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps content centred and readable on wide screens.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.vertical = 56});

  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20 : 32,
            vertical: compact ? vertical * 0.7 : vertical,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final compact = context.isCompact;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 32,
              vertical: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLockup(size: compact ? 30 : 36),
                  ),
                ),
                const ThemeToggleButton(),
                const SizedBox(width: 4),
                AppButton(
                  label: 'Sign in',
                  style: AppButtonStyle.text,
                  expand: false,
                  onPressed: () => context.go('/login'),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Get started',
                    expand: false,
                    onPressed: () => context.go('/register'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compact = context.isCompact;

    final headlineStyle = theme.textTheme.displayMedium?.copyWith(
      fontSize: compact ? 38 : (wide ? 56 : 46),
      height: 1.05,
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.softBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Live classes  ·  Notes  ·  Mobile money',
              style: TextStyle(
                color: p.softInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Text.rich(
            TextSpan(
              style: headlineStyle,
              children: [
                const TextSpan(text: 'Learn live,\n'),
                TextSpan(
                  text: 'one hop at a time.',
                  style: TextStyle(
                    color: p.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Join real classes with real teachers, from your phone. '
              'Pick a course, pay once in FCFA with MTN or Orange Money, '
              'and start learning.',
              style: TextStyle(color: p.ink2, fontSize: 18, height: 1.55),
            ),
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: compact ? double.infinity : 210,
                child: AppButton(
                  label: 'Create a free account',
                  onPressed: () => context.go('/register'),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 140,
                child: AppButton(
                  label: 'Sign in',
                  style: AppButtonStyle.outlined,
                  onPressed: () => context.go('/login'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Creating an account is free. You only pay when you register '
          'for a course.',
          style: TextStyle(color: p.ink2, fontSize: 14),
        ),
      ],
    );

    final art = FadeSlideIn(
      delay: const Duration(milliseconds: 200),
      offset: 24,
      child: const _ClassPreview(),
    );

    return _Section(
      vertical: 64,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: text),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: art),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 36), art],
            ),
    );
  }
}

/// A small illustration of a live class, drawn with widgets (no images to
/// download, so it costs no data).
class _ClassPreview extends StatelessWidget {
  const _ClassPreview();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.line),
            boxShadow: [
              BoxShadow(
                color: p.ink.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: p.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live now',
                    style: TextStyle(
                      color: p.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Mathematics, Form 5',
                    style: TextStyle(color: p.ink2, fontSize: 13),
                  ),
                ],
              ),
              Divider(height: 28, color: p.line),
              const _Bubble(
                who: 'Instructor',
                text: 'Open your notes at page 12. We start with fractions.',
                mine: false,
              ),
              const SizedBox(height: 10),
              const _VoiceBubble(),
              const SizedBox(height: 10),
              const _Bubble(
                who: 'Amina',
                text: 'Got it, thank you!',
                mine: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_open_rounded, size: 18, color: p.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat is open to the class',
                        style: TextStyle(color: p.ink2, fontSize: 14),
                      ),
                    ),
                    Icon(Icons.pan_tool_outlined, size: 18, color: p.ink2),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: -10,
          bottom: -22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: p.accentInk, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Payment received',
                  style: TextStyle(
                    color: p.accentInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.who, required this.text, required this.mine});

  final String who;
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? p.accent : p.softBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                who,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: mine ? p.accentInk.withValues(alpha: 0.8) : p.softInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: mine ? p.accentInk : p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const heights = <double>[8, 14, 20, 12, 22, 16, 9, 18, 24, 13, 8, 17, 11];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.softBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill_rounded, color: p.accent, size: 30),
            const SizedBox(width: 10),
            for (final h in heights)
              Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 10),
            Text('0:24', style: TextStyle(color: p.ink2, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Features
// ---------------------------------------------------------------------------

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const items = [
      _FeatureData(
        icon: Icons.forum_outlined,
        title: 'Live class chat',
        body: 'Text, voice notes, photos and files in a real-time room. '
            'Your teacher decides when you can speak.',
      ),
      _FeatureData(
        icon: Icons.menu_book_outlined,
        title: 'Notes and materials',
        body: 'Course notes and files are ready before the first class, '
            'and only registered students can open them.',
      ),
      _FeatureData(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Pay with mobile money',
        body: 'One fixed fee in FCFA through MTN or Orange Money. '
            'No bank card needed.',
      ),
      _FeatureData(
        icon: Icons.data_saver_on_rounded,
        title: 'Built for low data',
        body: 'Light pages and small images. Big files only download '
            'when you tap them.',
      ),
    ];

    return Container(
      color: p.surface,
      child: _Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Everything for a good class, in one place',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No more scattered groups and screenshots.',
              style: TextStyle(color: p.ink2, fontSize: 16),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 16.0;
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final item in items)
                      SizedBox(width: width, child: _FeatureCard(data: item)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data});

  final _FeatureData data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: p.softBg, shape: BoxShape.circle),
            child: Icon(data.icon, color: p.softInk, size: 22),
          ),
          const SizedBox(height: 16),
          Text(data.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: TextStyle(color: p.ink2, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How it works
// ---------------------------------------------------------------------------

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const steps = [
      ('Create your account', 'Sign up with Google or your email in a minute.'),
      ('Choose a course', 'Read the description and notes, then register.'),
      ('Pay once', 'Pay the fixed fee by MTN or Orange Money. We confirm it.'),
      ('Join the live class', 'Get a reminder, open the class and learn.'),
    ];

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 20.0;
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 24,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: p.accentInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            steps[i].$1,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            steps[i].$2,
                            style: TextStyle(
                              color: p.ink2,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
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

// ---------------------------------------------------------------------------
// Teachers
// ---------------------------------------------------------------------------

class _TeacherBand extends StatelessWidget {
  const _TeacherBand();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final compact = context.isCompact;
    return _Section(
      vertical: 24,
      child: Container(
        padding: EdgeInsets.all(compact ? 24 : 40),
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Wrap(
          spacing: 32,
          runSpacing: 24,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share what you know',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: p.accentInk,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Teach live classes to students across Cameroon. We handle '
                    'registration and payment, you focus on teaching. '
                    'Every teacher is approved by an administrator.',
                    style: TextStyle(
                      color: p.accentInk.withValues(alpha: 0.9),
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accentInk,
                foregroundColor: p.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => context.go('/join-teacher'),
              child: const Text('Apply as a teacher'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Section(
      vertical: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLockup(size: 34),
          const SizedBox(height: 18),
          Wrap(
            spacing: 4,
            children: [
              AppButton(
                label: 'Sign in',
                style: AppButtonStyle.text,
                expand: false,
                onPressed: () => context.go('/login'),
              ),
              AppButton(
                label: 'Create an account',
                style: AppButtonStyle.text,
                expand: false,
                onPressed: () => context.go('/register'),
              ),
              AppButton(
                label: 'Teach with us',
                style: AppButtonStyle.text,
                expand: false,
                onPressed: () => context.go('/join-teacher'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '© ${DateTime.now().year} Research Hop. All rights reserved.',
            style: TextStyle(color: p.ink2, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
