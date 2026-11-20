import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final p = context.palette;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? p.dangerBg : p.ink,
        content: Text(
          message,
          style: TextStyle(
            color: error ? p.danger : p.bg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
}
