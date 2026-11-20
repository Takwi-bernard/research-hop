import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/providers.dart';
import '../../../core/utils/errors.dart';
import '../data/auth_repository.dart';
import '../domain/models.dart';
import '../domain/session_state.dart';

/// Single source of truth for "who is signed in and what may they see".
/// It follows Supabase sign-in events and loads the profile in ONE request.
class SessionNotifier extends Notifier<SessionState> {
  bool _recovery = false;
  bool _busy = false;
  bool _again = false;
  StreamSubscription<AuthState>? _subscription;

  @override
  SessionState build() {
    final client = ref.watch(supabaseClientProvider);

    _subscription = client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          _recovery = true;
          refresh();
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.signedOut:
          refresh();
        default:
          // Token refreshes and similar events change nothing we show.
          break;
      }
    });
    ref.onDispose(() => _subscription?.cancel());

    Future<void>.microtask(refresh);
    return const SessionState.loading();
  }

  /// Reloads the session quietly (no loading screen). Safe to call often.
  Future<void> refresh() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final next = await _load();
        if (next != state) state = next;
      } while (_again);
    } finally {
      _busy = false;
    }
  }

  /// Used by the "Try again" button on the connection problem screen.
  Future<void> retry() async {
    state = const SessionState.loading();
    await refresh();
  }

  /// Called after the person has chosen a new password.
  Future<void> finishRecovery() async {
    _recovery = false;
    await refresh();
  }

  Future<SessionState> _load() async {
    final client = ref.read(supabaseClientProvider);
    final session = client.auth.currentSession;

    if (session == null) {
      _recovery = false;
      return const SessionState.signedOut();
    }
    if (_recovery) {
      return const SessionState.passwordRecovery();
    }

    try {
      // One request: the profile plus this person's teacher application.
      // "!user_id" tells the database which of the two links to follow.
      final Future<Map<String, dynamic>?> request = client
          .from('profiles')
          .select(
            'id, role, full_name, phone, city, avatar_url, '
            'teacher_applications!user_id(status, rejection_reason)',
          )
          .eq('id', session.user.id)
          .maybeSingle();
      // Never wait forever on a weak connection: after 15 s we show the
      // "Try again" screen instead of a loading logo.
      final row = await request.timeout(const Duration(seconds: 15));

      if (row == null) {
        return const SessionState.error(
          'Your account is not ready yet. Please try again in a moment, '
          'or contact the administrator.',
        );
      }

      final wantsTeacher = await TeacherIntentStore.read();
      return SessionState.ready(
        profile: Profile.fromRow(row),
        application: _parseApplication(row['teacher_applications']),
        wantsTeacher: wantsTeacher,
      );
    } catch (error) {
      return SessionState.error(friendlyError(error));
    }
  }

  static TeacherApplication? _parseApplication(Object? raw) {
    final Object? item = raw is List ? (raw.isEmpty ? null : raw.first) : raw;
    if (item is! Map) return null;
    return TeacherApplication(
      status: applicationStatusFromString(item['status'] as String?),
      rejectionReason: item['rejection_reason'] as String?,
    );
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
