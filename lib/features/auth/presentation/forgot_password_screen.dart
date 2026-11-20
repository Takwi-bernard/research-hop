import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/snack.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _sent
            ? Column(
                key: const ValueKey('sent'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration:
                        BoxDecoration(color: p.softBg, shape: BoxShape.circle),
                    child: Icon(Icons.mark_email_unread_outlined,
                        color: p.softInk),
                  ),
                  const SizedBox(height: 22),
                  Text('Check your inbox',
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    'If ${_email.text.trim()} has an account, we sent a link '
                    'to choose a new password.',
                    style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Back to sign in',
                    onPressed: () => context.go('/login'),
                  ),
                ],
              )
            : Form(
                key: const ValueKey('form'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: Text('Reset your password',
                          style: theme.textTheme.headlineMedium),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email and we will send you a link to choose '
                      'a new password.',
                      style:
                          TextStyle(color: p.ink2, fontSize: 16, height: 1.45),
                    ),
                    const SizedBox(height: 26),
                    AppTextField(
                      label: 'Email',
                      hint: 'you@example.com',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      validator: validateEmail,
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: 'Send reset link',
                      loading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Back to sign in',
                      style: AppButtonStyle.text,
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
