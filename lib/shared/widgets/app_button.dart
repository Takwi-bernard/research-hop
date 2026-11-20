import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

enum AppButtonStyle { filled, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.loading = false,
    this.leading,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool loading;
  final Widget? leading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;

    final Color foreground;
    switch (style) {
      case AppButtonStyle.filled:
        foreground = p.accentInk;
      case AppButtonStyle.outlined:
        foreground = p.ink;
      case AppButtonStyle.text:
        foreground = p.accent;
    }

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: loading
          ? SizedBox(
              key: const ValueKey('spinner'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: foreground,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final minimumSize = Size(expand ? double.infinity : 0, 54);
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    switch (style) {
      case AppButtonStyle.filled:
        return FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: minimumSize,
            backgroundColor: p.accent,
            foregroundColor: p.accentInk,
            disabledBackgroundColor:
                p.accent.withValues(alpha: loading ? 0.85 : 0.4),
            disabledForegroundColor: p.accentInk,
            shape: shape,
            textStyle: textStyle,
            elevation: 0,
          ),
          child: content,
        );
      case AppButtonStyle.outlined:
        return OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: minimumSize,
            backgroundColor: p.surface,
            foregroundColor: p.ink,
            disabledForegroundColor: p.ink2,
            side: BorderSide(color: p.line),
            shape: shape,
            textStyle: textStyle,
          ),
          child: content,
        );
      case AppButtonStyle.text:
        return TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(expand ? double.infinity : 0, 48),
            foregroundColor: p.accent,
            shape: shape,
            textStyle: textStyle,
          ),
          child: content,
        );
    }
  }
}
