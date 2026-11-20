import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/errors.dart';
import 'app_button.dart';

/// Shows data as soon as there is some, keeps showing it while a live update
/// reloads in the background (no flicker), and shows a retry on errors.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = value.value;
    if (data != null) return builder(data);
    if (value.hasError) {
      final p = context.palette;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: p.ink2, size: 32),
            const SizedBox(height: 12),
            Text(
              friendlyError(value.error!),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.ink2, fontSize: 15),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Try again',
              style: AppButtonStyle.outlined,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
    );
  }
}
