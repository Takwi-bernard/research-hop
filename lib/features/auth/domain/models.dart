import 'package:flutter/foundation.dart';

enum AppRole { student, teacher, admin }

enum ApplicationStatus { pending, approved, rejected, suspended }

AppRole appRoleFromString(String? value) {
  return AppRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AppRole.student,
  );
}

ApplicationStatus applicationStatusFromString(String? value) {
  return ApplicationStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ApplicationStatus.pending,
  );
}

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.phone,
    this.city,
    this.avatarUrl,
  });

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      role: appRoleFromString(row['role'] as String?),
      fullName: (row['full_name'] as String?) ?? '',
      phone: row['phone'] as String?,
      city: row['city'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  final String id;
  final AppRole role;
  final String fullName;
  final String? phone;
  final String? city;
  final String? avatarUrl;

  String get firstName {
    final text = fullName.trim();
    if (text.isEmpty) return '';
    return text.split(RegExp(r'\s+')).first;
  }

  /// A friendly name for greetings. Never empty.
  String get displayName => firstName.isEmpty ? 'there' : firstName;

  String get initial {
    final text = fullName.trim();
    return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
  }

  @override
  bool operator ==(Object other) {
    return other is Profile &&
        other.id == id &&
        other.role == role &&
        other.fullName == fullName &&
        other.phone == phone &&
        other.city == city &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode => Object.hash(id, role, fullName, phone, city, avatarUrl);
}

@immutable
class TeacherApplication {
  const TeacherApplication({required this.status, this.rejectionReason});

  final ApplicationStatus status;
  final String? rejectionReason;

  @override
  bool operator ==(Object other) {
    return other is TeacherApplication &&
        other.status == status &&
        other.rejectionReason == rejectionReason;
  }

  @override
  int get hashCode => Object.hash(status, rejectionReason);
}
