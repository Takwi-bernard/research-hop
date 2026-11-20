import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Shown instead of the app when the env file is missing or wrong.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Research Hop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _ConfigErrorBody(message: message),
    );
  }
}

class _ConfigErrorBody extends StatelessWidget {
  const _ConfigErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: p.warnBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings_outlined, color: p.warnInk),
                ),
                const SizedBox(height: 20),
                Text(
                  'One setting is missing',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: p.ink2, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
