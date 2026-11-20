import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'nav_destinations.dart';
import 'page_frame.dart';

/// Shown on pages whose real content is built in a later module.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.item});

  final NavItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PageFrame(
      child: FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: p.softBg, shape: BoxShape.circle),
                child: Icon(item.selectedIcon, color: p.softInk),
              ),
              const SizedBox(height: 18),
              Text(item.label, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                item.comingWith,
                style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
