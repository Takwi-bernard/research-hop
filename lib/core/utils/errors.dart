import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'app_exception.dart';
import 'upload_exception.dart';

/// Turns any error into a short sentence a student can understand.
String friendlyError(Object error) {
  if (error is UploadException) return error.message;
  if (error is AppException) return error.message;
  final text = error.toString();

  if (_looksLikeNetworkProblem(text)) {
    return 'Could not reach ${Env.host}. Check your data and try again. '
        '(If your data is fine, the project address in app.env is wrong.)';
  }

  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email first. Check your inbox.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (message.contains('password')) {
      return error.message;
    }
    return 'We could not sign you in. Please try again.';
  }

  if (error is PostgrestException) {
    // Our own database messages are already written for people.
    return error.message;
  }

  return 'Something went wrong. Please try again.';
}

bool _looksLikeNetworkProblem(String text) {
  const patterns = <String>[
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Failed to fetch',
    'XMLHttpRequest',
    'NetworkError',
    'Connection refused',
    'Connection closed',
    'timed out',
    'TimeoutException',
  ];
  return patterns.any(text.contains);
}
