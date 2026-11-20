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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.setTeacherIntent(false);
      await repo.signInWithPassword(
        email: _email.text,
        password: _password.text,
      );
      // The router moves on by itself once the session is ready.
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
      await repo.setTeacherIntent(false);
      await repo.signInWithGoogle();
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final anyBusy = _busy || _googleBusy;

    return AuthScaffold(
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Text('Welcome back', style: theme.textTheme.headlineMedium),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Text(
                  'Sign in to continue your courses and live classes.',
                  style: TextStyle(color: p.ink2, fontSize: 16, height: 1.45),
                ),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: AppButton(
                  label: 'Continue with Google',
                  style: AppButtonStyle.outlined,
                  leading: const GoogleLogo(),
                  loading: _googleBusy,
                  onPressed: anyBusy ? null : _google,
                ),
              ),
              const SizedBox(height: 20),
              const FadeSlideIn(
                delay: Duration(milliseconds: 160),
                child: OrDivider(),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
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
                delay: const Duration(milliseconds: 240),
                child: AppTextField(
                  label: 'Password',
                  hint: 'Your password',
                  controller: _password,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: validatePasswordRequired,
                  onSubmitted: (_) => anyBusy ? null : _signIn(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: 'Forgot password?',
                  style: AppButtonStyle.text,
                  expand: false,
                  onPressed: () => context.push('/forgot-password'),
                ),
              ),
              const SizedBox(height: 4),
              FadeSlideIn(
                delay: const Duration(milliseconds: 280),
                child: AppButton(
                  label: 'Sign in',
                  loading: _busy,
                  onPressed: anyBusy ? null : _signIn,
                ),
              ),
              const SizedBox(height: 28),
              _FooterLink(
                question: 'New to Research Hop?',
                action: 'Create an account',
                onTap: () => context.go('/register'),
              ),
              const SizedBox(height: 4),
              _FooterLink(
                question: 'Teaching with us?',
                action: 'Apply as a teacher',
                onTap: () => context.go('/join-teacher'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: TextStyle(color: p.ink2, fontSize: 15)),
        AppButton(
          label: action,
          style: AppButtonStyle.text,
          expand: false,
          onPressed: onTap,
        ),
      ],
    );
  }
}
