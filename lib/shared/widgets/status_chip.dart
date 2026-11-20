import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

enum ChipTone { neutral, good, warn, bad }

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color bg;
    final Color fg;
    switch (tone) {
      case ChipTone.good:
        bg = p.softBg;
        fg = p.softInk;
      case ChipTone.warn:
        bg = p.warnBg;
        fg = p.warnInk;
      case ChipTone.bad:
        bg = p.dangerBg;
        fg = p.danger;
      case ChipTone.neutral:
        bg = p.surface2;
        fg = p.ink2;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
