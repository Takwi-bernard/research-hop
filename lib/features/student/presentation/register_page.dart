import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../auth/application/session_notifier.dart';
import '../../shell/page_frame.dart';
import '../application/student_providers.dart';
import '../data/student_models.dart';

/// Registration form, prefilled from the student's profile.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  bool _filled = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit(CatalogCourse course) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(studentRepositoryProvider).register(
            courseId: course.id,
            fullName: _name.text,
            phone: _phone.text,
            city: _city.text,
          );
      ref.invalidate(myRegistrationsProvider);
      if (!mounted) return;
      if (course.feeXaf == 0) {
        showAppSnack(context, 'You are registered. An administrator will confirm your place.');
        context.go('/student/courses/${course.id}');
      } else {
        context.go('/student/pay/$id');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final catalog = ref.watch(catalogProvider);
    final profile = ref.watch(sessionProvider).profile;
    if (!_filled && profile != null) {
      _name.text = profile.fullName;
      _phone.text = profile.phone ?? '';
      _city.text = profile.city ?? '';
      _filled = true;
    }

    CatalogCourse? course;
    for (final c in catalog.value ?? const <CatalogCourse>[]) {
      if (c.id == widget.courseId) course = c;
    }

    return PageFrame(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/student/courses/${widget.courseId}'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
            ),
          ),
          const SizedBox(height: 6),
          if (course == null)
            AsyncBody<List<CatalogCourse>>(
              value: catalog,
              onRetry: () => ref.invalidate(catalogProvider),
              builder: (_) => const Text('This course is not available.'),
            )
          else ...[
            Text('Register', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.softBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      style: TextStyle(
                        color: p.softInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    course.feeXaf == 0 ? 'Free' : formatXaf(course.feeXaf),
                    style: TextStyle(
                      color: p.softInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Full name',
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      validator: validateName,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Phone number',
                      helper: 'We use it to reach you about this course',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: validatePhone,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'City',
                      controller: _city,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: course.feeXaf == 0
                          ? 'Register'
                          : 'Continue to payment',
                      loading: _busy,
                      onPressed: _busy ? null : () => _submit(course!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              course.feeXaf == 0
                  ? 'Your place is confirmed by an administrator.'
                  : 'You pay once, in FCFA. Your place is confirmed by an '
                      'administrator after payment.',
              style: TextStyle(color: p.ink2, fontSize: 14, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
