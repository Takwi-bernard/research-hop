import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/web_files.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/theme_mode_switcher.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/session_notifier.dart';
import '../../notifications/presentation/push_settings_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/models.dart';
import '../../shell/nav_destinations.dart';
import '../../shell/page_frame.dart';
import '../data/profile_repository.dart';

/// One profile page for every role: photo, details, password, appearance.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  bool _filled = false;
  bool _saving = false;
  bool _photoBusy = false;
  double _photoProgress = 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  void _fill(Profile profile) {
    _name.text = profile.fullName;
    _phone.text = profile.phone ?? '';
    _city.text = profile.city ?? '';
    _filled = true;
  }

  Future<void> _save(Profile profile) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateDetails(
            userId: profile.id,
            fullName: _name.text,
            phone: _phone.text,
            city: _city.text,
          );
      await ref.read(sessionProvider.notifier).refresh();
      if (mounted) showAppSnack(context, 'Profile saved');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto(Profile profile) async {
    final picked = await pickFile(extensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (picked == null) return;
    setState(() {
      _photoBusy = true;
      _photoProgress = 0;
    });
    try {
      // Shrink to a small square first: less data, faster upload.
      final small = await compressImage(
        picked.bytes,
        maxSide: 512,
        quality: 0.85,
        square: true,
      );
      await ref.read(profileRepositoryProvider).uploadAvatar(
            userId: profile.id,
            bytes: small,
            oldUrl: profile.avatarUrl,
            onProgress: (f) {
              if (mounted) setState(() => _photoProgress = f);
            },
          );
      await ref.read(sessionProvider.notifier).refresh();
      if (mounted) showAppSnack(context, 'Photo updated');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto(Profile profile) async {
    setState(() {
      _photoBusy = true;
      _photoProgress = 0;
    });
    try {
      await ref.read(profileRepositoryProvider).removeAvatar(
            userId: profile.id,
            oldUrl: profile.avatarUrl,
          );
      await ref.read(sessionProvider.notifier).refresh();
      if (mounted) showAppSnack(context, 'Photo removed');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _applyAsTeacher() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.setTeacherIntent(true);
    await ref.read(sessionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    if (profile == null) return const SizedBox.shrink();
    if (!_filled) _fill(profile);

    final repo = ref.watch(profileRepositoryProvider);
    final email = repo.user?.email ?? '';
    final method = repo.signInMethod == 'google' ? 'Google' : 'Email and password';

    return PageFrame(
      maxWidth: 680,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          SectionCard(
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    UserAvatar(
                      initial: profile.initial,
                      url: profile.avatarUrl,
                      size: 88,
                    ),
                    if (_photoBusy)
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: CircularProgressIndicator(
                          value: _photoProgress > 0 ? _photoProgress : null,
                          strokeWidth: 4,
                          color: p.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName.isEmpty ? 'Your name' : profile.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      StatusChip(roleLabel(profile.role), tone: ChipTone.good),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          AppButton(
                            label: profile.avatarUrl == null
                                ? 'Add a photo'
                                : 'Change photo',
                            style: AppButtonStyle.outlined,
                            expand: false,
                            onPressed: _photoBusy ? null : () => _changePhoto(profile),
                          ),
                          if (profile.avatarUrl != null)
                            AppButton(
                              label: 'Remove',
                              style: AppButtonStyle.text,
                              expand: false,
                              onPressed:
                                  _photoBusy ? null : () => _removePhoto(profile),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Personal details',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Full name',
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    validator: validateName,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Phone number',
                    helper: profile.role == AppRole.student
                        ? 'Used to prefill your course registrations'
                        : null,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? null : validatePhone(v),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'City',
                    controller: _city,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Save changes',
                    loading: _saving,
                    onPressed: _saving ? null : () => _save(profile),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _InfoRow(label: 'Email', value: email.isEmpty ? '-' : email),
                _InfoRow(label: 'Sign-in method', value: method),
                const SizedBox(height: 10),
                AppButton(
                  label: repo.signInMethod == 'google'
                      ? 'Set a password'
                      : 'Change password',
                  style: AppButtonStyle.outlined,
                  expand: false,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _PasswordDialog(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const PushSettingsCard(),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'System follows your phone or computer.',
                  style: TextStyle(color: p.ink2, fontSize: 14),
                ),
                const SizedBox(height: 14),
                const ThemeModeSwitcher(),
              ],
            ),
          ),
          if (session.canApplyAsTeacher) ...[
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teach on Research Hop',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Share your knowledge. An administrator reviews every '
                    'application.',
                    style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Apply as a teacher',
                    style: AppButtonStyle.outlined,
                    expand: false,
                    onPressed: _applyAsTeacher,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Sign out',
            style: AppButtonStyle.text,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: p.ink2, fontSize: 14.5)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).changePassword(_password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, 'Password updated');
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      backgroundColor: p.surface,
      title: const Text('New password'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'New password',
                helper: 'At least 8 characters',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: validateNewPassword,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Confirm password',
                controller: _confirm,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v == _password.text ? null : 'The two passwords do not match',
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: p.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
