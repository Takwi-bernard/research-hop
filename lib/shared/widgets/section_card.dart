import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(18);
    return Material(
      color: p.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Title (+ optional subtitle and action) shown at the top of a page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(color: p.ink2, fontSize: 15, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Horizontal pill tabs with optional counts.
class ChipTabs extends StatelessWidget {
  const ChipTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.counts,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: i == selected,
                showCheckmark: false,
                onSelected: (_) => onChanged(i),
                backgroundColor: p.surface,
                selectedColor: p.softBg,
                side: BorderSide(color: i == selected ? p.accent : p.line),
                label: Text(
                  counts == null ? labels[i] : '${labels[i]}  ${counts![i]}',
                  style: TextStyle(
                    color: i == selected ? p.softInk : p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
