import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/config_error_app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Env.load();
  final problem = Env.problem;
  if (problem != null) {
    runApp(ConfigErrorApp(message: problem));
    return;
  }

  // On a weak connection restoring the saved session can take very long.
  // Wait at most 10 seconds, then open the app anyway: it keeps retrying in
  // the background and the boot screen offers "Try again".
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ).timeout(const Duration(seconds: 10));
  } catch (_) {
    // Supabase.instance is already created at this point; see boot screen.
  }

  runApp(const ProviderScope(child: ResearchHopApp()));
}
