import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/errors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/snack.dart';
import '../../shared/widgets/theme_mode_switcher.dart';
import '../../shared/widgets/user_avatar.dart';
import '../auth/application/session_notifier.dart';
import '../auth/data/auth_repository.dart';
import '../auth/domain/models.dart';
import 'nav_destinations.dart';

/// Small round avatar showing the first letter of the person's name.
class AvatarButton extends ConsumerWidget {
  const AvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    return Tooltip(
      message: 'Account',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showAccountSheet(context),
        child: UserAvatar(
          initial: profile?.initial ?? '?',
          url: profile?.avatarUrl,
          size: 38,
        ),
      ),
    );
  }
}

Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  bool _busy = false;

  Future<void> _applyAsTeacher() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.setTeacherIntent(true);
      await ref.read(sessionProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  initial: profile?.initial ?? '?',
                  url: profile?.avatarUrl,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName.isNotEmpty == true
                            ? profile!.fullName
                            : 'Your account',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        roleLabel(profile?.role ?? AppRole.student),
                        style: TextStyle(color: p.ink2, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Profile and settings',
              style: AppButtonStyle.outlined,
              onPressed: () {
                final role = profile?.role ?? AppRole.student;
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go(profilePathFor(role));
              },
            ),
            const SizedBox(height: 22),
            Text('Appearance', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            const ThemeModeSwitcher(),
            if (session.canApplyAsTeacher) ...[
              const SizedBox(height: 22),
              AppButton(
                label: 'Apply as a teacher',
                style: AppButtonStyle.outlined,
                loading: _busy,
                onPressed: _busy ? null : _applyAsTeacher,
              ),
            ],
            const SizedBox(height: 10),
            AppButton(
              label: 'Sign out',
              style: AppButtonStyle.text,
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
