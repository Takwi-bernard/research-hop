import 'package:flutter/material.dart';

import '../auth/domain/models.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.comingWith,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  /// Short note shown on the placeholder page until the real page is built.
  final String comingWith;
}

const List<NavItem> studentNav = [
  NavItem(
    label: 'Home',
    path: '/student',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    comingWith: 'Your courses and upcoming classes will appear here.',
  ),
  NavItem(
    label: 'Courses',
    path: '/student/courses',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
    comingWith: 'Browse courses, register and pay here.',
  ),
  NavItem(
    label: 'Alerts',
    path: '/student/alerts',
    icon: Icons.notifications_none_rounded,
    selectedIcon: Icons.notifications_rounded,
    comingWith: 'Class reminders and announcements will show here.',
  ),
  NavItem(
    label: 'Profile',
    path: '/student/profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    comingWith: 'Your details will be editable here.',
  ),
];

const List<NavItem> teacherNav = [
  NavItem(
    label: 'Home',
    path: '/teacher',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    comingWith: 'Your day at a glance will appear here.',
  ),
  NavItem(
    label: 'My courses',
    path: '/teacher/courses',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
    comingWith: 'Courses assigned to you will be listed here.',
  ),
  NavItem(
    label: 'Classes',
    path: '/teacher/classes',
    icon: Icons.event_outlined,
    selectedIcon: Icons.event_rounded,
    comingWith: 'Schedule classes and run live chat here.',
  ),
  NavItem(
    label: 'Alerts',
    path: '/teacher/alerts',
    icon: Icons.notifications_none_rounded,
    selectedIcon: Icons.notifications_rounded,
    comingWith: 'Notifications will show here.',
  ),
];

const List<NavItem> adminNav = [
  NavItem(
    label: 'Overview',
    path: '/admin',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    comingWith: 'Key numbers will appear here.',
  ),
  NavItem(
    label: 'Teachers',
    path: '/admin/teachers',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
    comingWith: 'Approve teachers and assign them to courses.',
  ),
  NavItem(
    label: 'Courses',
    path: '/admin/courses',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
    comingWith: 'Create courses, notes and fees.',
  ),
  NavItem(
    label: 'Registrations',
    path: '/admin/registrations',
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg_rounded,
    comingWith: 'Approve paid registrations with one tap.',
  ),
  NavItem(
    label: 'Payments',
    path: '/admin/payments',
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
    comingWith: 'See every payment and record cash.',
  ),
];

List<NavItem> navFor(AppRole role) {
  switch (role) {
    case AppRole.student:
      return studentNav;
    case AppRole.teacher:
      return teacherNav;
    case AppRole.admin:
      return adminNav;
  }
}

String roleLabel(AppRole role) {
  switch (role) {
    case AppRole.student:
      return 'Student';
    case AppRole.teacher:
      return 'Teacher';
    case AppRole.admin:
      return 'Administrator';
  }
}

/// Where the profile page lives for each role.
String profilePathFor(AppRole role) => '/${role.name}/profile';
