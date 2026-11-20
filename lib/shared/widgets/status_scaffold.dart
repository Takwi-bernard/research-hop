import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_mode_switcher.dart';

/// A calm, centred page for states like "in review", "suspended" or "offline".
class StatusScaffold extends StatelessWidget {
  const StatusScaffold({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
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
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Positioned(top: 8, right: 12, child: ThemeToggleButton()),
          ],
        ),
      ),
    );
  }
}
