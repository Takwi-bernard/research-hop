import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'or use your email'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: p.ink2, fontSize: 13)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
