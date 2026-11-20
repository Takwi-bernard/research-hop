import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/snack.dart';
import '../application/session_notifier.dart';
import '../data/auth_repository.dart';

/// Opened from the link in the password reset email.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (mounted) showAppSnack(context, 'Password updated');
      await ref.read(sessionProvider.notifier).finishRecovery();
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);

    return AuthScaffold(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(
              child: Text('Choose a new password',
                  style: theme.textTheme.headlineMedium),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick something you have not used on other sites.',
              style: TextStyle(color: p.ink2, fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 26),
            AppTextField(
              label: 'New password',
              helper: 'At least 8 characters',
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: validateNewPassword,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirm new password',
              controller: _confirm,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: (value) => value == _password.text
                  ? null
                  : 'The two passwords do not match',
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Save password',
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
