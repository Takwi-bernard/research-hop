import 'package:flutter/foundation.dart';

import 'models.dart';

enum SessionStatus { loading, signedOut, passwordRecovery, ready, error }

/// Everything the router needs to know about who is using the app.
@immutable
class SessionState {
  const SessionState._({
    required this.status,
    this.profile,
    this.application,
    this.wantsTeacher = false,
    this.message,
  });

  const SessionState.loading() : this._(status: SessionStatus.loading);

  const SessionState.signedOut() : this._(status: SessionStatus.signedOut);

  const SessionState.passwordRecovery()
      : this._(status: SessionStatus.passwordRecovery);

  const SessionState.error(String message)
      : this._(status: SessionStatus.error, message: message);

  const SessionState.ready({
    required Profile profile,
    TeacherApplication? application,
    bool wantsTeacher = false,
  }) : this._(
          status: SessionStatus.ready,
          profile: profile,
          application: application,
          wantsTeacher: wantsTeacher,
        );

  final SessionStatus status;
  final Profile? profile;
  final TeacherApplication? application;

  /// True when this person chose "Apply as a teacher" and has not finished yet.
  final bool wantsTeacher;

  /// Error text when [status] is [SessionStatus.error].
  final String? message;

  /// A student who has no application yet, or whose application was rejected.
  bool get canApplyAsTeacher {
    if (status != SessionStatus.ready) return false;
    if (profile?.role != AppRole.student) return false;
    final app = application;
    return app == null || app.status == ApplicationStatus.rejected;
  }

  @override
  bool operator ==(Object other) {
    return other is SessionState &&
        other.status == status &&
        other.profile == profile &&
        other.application == application &&
        other.wantsTeacher == wantsTeacher &&
        other.message == message;
  }

  @override
  int get hashCode =>
      Object.hash(status, profile, application, wantsTeacher, message);
}
