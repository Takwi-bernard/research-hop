import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/auth_scaffold.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/or_divider.dart';
import '../../../shared/widgets/snack.dart';
import '../data/auth_repository.dart';

/// Creates an account. With [asTeacher] the person is taken to the teacher
/// application form afterwards; an administrator must approve them.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, required this.asTeacher});

  final bool asTeacher;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  String? _confirmationSentTo;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.setTeacherIntent(widget.asTeacher);
      final needsConfirmation = await repo.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (needsConfirmation && mounted) {
        setState(() => _confirmationSentTo = _email.text.trim());
      }
      // Otherwise the router moves on by itself.
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleBusy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.setTeacherIntent(widget.asTeacher);
      await repo.signInWithGoogle();
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _confirmationSentTo;
    return AuthScaffold(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: sentTo != null
            ? _ConfirmPanel(
                key: const ValueKey('confirm'),
                email: sentTo,
                onBack: () => context.go('/login'),
              )
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final anyBusy = _busy || _googleBusy;
    final teacher = widget.asTeacher;

    return AutofillGroup(
      key: const ValueKey('form'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(
              child: Text(
                teacher ? 'Teach with Research Hop' : 'Create your account',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Text(
                teacher
                    ? 'Create your account, then tell us about your experience. '
                        'An administrator approves every teacher before they '
                        'can start.'
                    : 'Join courses, attend live classes and keep all your '
                        'notes in one place.',
                style: TextStyle(color: p.ink2, fontSize: 16, height: 1.45),
              ),
            ),
            const SizedBox(height: 26),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: AppButton(
                label: 'Sign up with Google',
                style: AppButtonStyle.outlined,
                leading: const GoogleLogo(),
                loading: _googleBusy,
                onPressed: anyBusy ? null : _google,
              ),
            ),
            const SizedBox(height: 20),
            const FadeSlideIn(
              delay: Duration(milliseconds: 160),
              child: OrDivider(label: 'or sign up with email'),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: AppTextField(
                label: 'Full name',
                hint: 'As you want it to appear',
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: validateName,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: AppTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 280),
              child: AppTextField(
                label: 'Password',
                helper: 'At least 8 characters',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: validateNewPassword,
                onSubmitted: (_) => anyBusy ? null : _submit(),
              ),
            ),
            const SizedBox(height: 22),
            FadeSlideIn(
              delay: const Duration(milliseconds: 320),
              child: AppButton(
                label: 'Create account',
                loading: _busy,
                onPressed: anyBusy ? null : _submit,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: TextStyle(color: p.ink2, fontSize: 15),
                ),
                AppButton(
                  label: 'Sign in',
                  style: AppButtonStyle.text,
                  expand: false,
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  teacher ? 'Looking to learn instead?' : 'Want to teach?',
                  style: TextStyle(color: p.ink2, fontSize: 15),
                ),
                AppButton(
                  label: teacher ? 'Create a student account' : 'Apply as a teacher',
                  style: AppButtonStyle.text,
                  expand: false,
                  onPressed: () =>
                      context.go(teacher ? '/register' : '/join-teacher'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({super.key, required this.email, required this.onBack});

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: p.softBg, shape: BoxShape.circle),
          child: Icon(Icons.mark_email_unread_outlined, color: p.softInk),
        ),
        const SizedBox(height: 22),
        Text('Check your inbox', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          'We sent a confirmation link to $email. Open it to activate your '
          'account, then sign in.',
          style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 28),
        AppButton(label: 'Back to sign in', onPressed: onBack),
      ],
    );
  }
}
