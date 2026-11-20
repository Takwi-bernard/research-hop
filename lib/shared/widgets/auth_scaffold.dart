import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/responsive.dart';
import 'brand.dart';
import 'theme_mode_switcher.dart';

/// Layout for sign-in style pages.
/// Wide screens: brand panel on the left, form on the right.
/// Phones and tablets: a single centred column with the logo on top.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.maxWidth = 440});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = context.screenSize == ScreenSize.expanded;
    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(
                  flex: 6,
                  child: _FormArea(
                    maxWidth: maxWidth,
                    showLockup: false,
                    child: child,
                  ),
                ),
              ],
            )
          : SafeArea(
              child: _FormArea(
                maxWidth: maxWidth,
                showLockup: true,
                child: child,
              ),
            ),
    );
  }
}

class _FormArea extends StatelessWidget {
  const _FormArea({
    required this.child,
    required this.maxWidth,
    required this.showLockup,
  });

  final Widget child;
  final double maxWidth;
  final bool showLockup;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 96),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showLockup) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => context.go('/'),
                              child: const BrandLockup(),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const Positioned(top: 8, right: 12, child: ThemeToggleButton()),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    return Container(
      color: p.accent,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLockup(onAccent: true),
                const Spacer(),
                Text(
                  'Learn, one hop at a time.',
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: p.accentInk),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    'Live classes, course notes and mobile money payments, '
                    'all in one place.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: p.accentInk.withValues(alpha: 0.88),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FeatureChip('Live class rooms'),
                    _FeatureChip('Notes and materials'),
                    _FeatureChip('Pay with MTN or Orange Money'),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.accentInk.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: p.accentInk,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
