import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A round profile picture, or the first letter of the name when there is
/// no picture (or it cannot load on a weak connection).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initial,
    this.url,
    this.size = 40,
  });

  final String initial;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.softBg, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: p.softInk,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );

    final address = url;
    if (address == null || address.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          address,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          errorBuilder: (context, error, stack) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      ),
    );
  }
}
