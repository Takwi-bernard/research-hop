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

/// Teachers tell us about themselves. The role only changes once an
/// administrator approves the application.
class TeacherApplyScreen extends ConsumerStatefulWidget {
  const TeacherApplyScreen({super.key});

  @override
  ConsumerState<TeacherApplyScreen> createState() => _TeacherApplyScreenState();
}

class _TeacherApplyScreenState extends ConsumerState<TeacherApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _qualification = TextEditingController();
  final _bio = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qualification.dispose();
    _bio.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.applyAsTeacher(
        qualification: _qualification.text,
        bio: _bio.text,
        phone: _phone.text,
      );
      await repo.setTeacherIntent(false);
      await ref.read(sessionProvider.notifier).refresh();
      // The router now shows the "in review" page.
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notNow() async {
    await ref.read(authRepositoryProvider).setTeacherIntent(false);
    await ref.read(sessionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);

    return AuthScaffold(
      maxWidth: 480,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideIn(
              child: Text(
                'Tell us about your teaching',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'An administrator reads every application. You will be told as '
              'soon as there is a decision.',
              style: TextStyle(color: p.ink2, fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 26),
            AppTextField(
              label: 'Highest qualification',
              hint: 'For example: BSc Mathematics, University of Bamenda',
              controller: _qualification,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              validator: validateMinLength(
                3,
                'Please tell us your qualification',
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'About you (optional)',
              hint: 'Subjects you teach and your experience',
              controller: _bio,
              maxLines: 4,
              maxLength: 1000,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Phone number',
              helper: 'Only the administrator sees this',
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: validatePhone,
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Submit application',
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Not now',
              style: AppButtonStyle.text,
              onPressed: _busy ? null : _notNow,
            ),
            AppButton(
              label: 'Sign out',
              style: AppButtonStyle.text,
              onPressed: _busy
                  ? null
                  : () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
