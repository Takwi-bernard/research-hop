import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/phone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../admin/data/admin_models.dart';
import '../../shell/page_frame.dart';
import '../application/student_providers.dart';
import '../data/student_models.dart';

enum _Stage { form, waiting, failed }

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.registrationId});

  final String registrationId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _filled = false;

  _Stage _stage = _Stage.form;
  bool _busy = false;
  String? _paymentId;
  String? _ussd;
  String? _failure;
  bool _slow = false;
  bool _checking = false;
  Timer? _timer;
  int _ticks = 0;
  bool _autoChecking = false;
  DateTime? _startedAt;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _start(MyRegistration reg) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final phone = normalizeCameroonPhone(_phone.text)!;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final started = await ref
          .read(studentRepositoryProvider)
          .startPayment(registrationId: reg.id, phone: phone);
      if (!mounted) return;
      setState(() {
        _paymentId = started.paymentId;
        _ussd = started.ussdCode;
        _stage = _Stage.waiting;
        _slow = false;
        _startedAt = DateTime.now();
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    final id = _paymentId;
    if (id == null) return;
    try {
      final result = await ref.read(studentRepositoryProvider).payment(id);
      if (!mounted || result == null) return;
      if (result.state == PayState.successful) {
        _timer?.cancel();
        ref.invalidate(myRegistrationsProvider);
        // The page now shows the "paid" state from the registration itself.
        setState(() {});
      } else if (result.state == PayState.failed) {
        _timer?.cancel();
        setState(() {
          _stage = _Stage.failed;
          _failure = result.failureReason;
        });
      } else {
        // The operator's callback can be late or lost, so every 8 seconds we
        // also ask the payment service to double-check with CamPay.
        _ticks++;
        if (_ticks % 2 == 0) _autoCheck(id);
        final started = _startedAt;
        if (started != null &&
            DateTime.now().difference(started) > const Duration(seconds: 75) &&
            !_slow) {
          setState(() => _slow = true);
        }
      }
    } catch (_) {
      // A dropped connection must not stop the waiting; try again next tick.
    }
  }

  Future<void> _autoCheck(String id) async {
    if (_autoChecking) return;
    _autoChecking = true;
    try {
      await ref.read(studentRepositoryProvider).checkPayment(id);
      if (mounted) await _poll();
    } catch (_) {
      // Quiet: the next round tries again.
    } finally {
      _autoChecking = false;
    }
  }

  Future<void> _checkNow() async {
    final id = _paymentId;
    if (id == null) return;
    setState(() => _checking = true);
    try {
      await ref.read(studentRepositoryProvider).checkPayment(id);
      await _poll();
      if (mounted) {
        showAppSnack(context, 'Checked. If you approved the prompt, this updates in a moment.');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _cancel(MyRegistration reg) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this registration?',
      message: 'You have not paid yet. You can register again any time.',
      confirmLabel: 'Cancel registration',
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(studentRepositoryProvider).cancelRegistration(reg.id);
      ref.invalidate(myRegistrationsProvider);
      if (mounted) context.go('/student/courses');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regsAsync = ref.watch(myRegistrationsProvider);
    MyRegistration? reg;
    for (final r in regsAsync.value ?? const <MyRegistration>[]) {
      if (r.id == widget.registrationId) reg = r;
    }

    return PageFrame(
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/student'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Home'),
            ),
          ),
          const SizedBox(height: 6),
          if (reg == null)
            AsyncBody<List<MyRegistration>>(
              value: regsAsync,
              onRetry: () => ref.invalidate(myRegistrationsProvider),
              builder: (_) => const Text('We could not find this registration.'),
            )
          else
            _content(context, reg),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, MyRegistration reg) {
    final p = context.palette;
    final theme = Theme.of(context);

    if (reg.status == RegStatus.paid || reg.status == RegStatus.approved) {
      _timer?.cancel();
      final approved = reg.status == RegStatus.approved;
      return SectionCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: p.softBg, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: p.softInk, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              approved ? 'You are in!' : 'Payment received',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              approved
                  ? 'You now have access to ${reg.courseTitle}.'
                  : 'Thank you. An administrator will confirm your place in '
                      '${reg.courseTitle} shortly. We will send you an alert.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.ink2, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: approved ? 'Open the course' : 'Go to my courses',
              onPressed: () => context.go(
                approved ? '/student/courses/${reg.courseId}' : '/student',
              ),
            ),
          ],
        ),
      );
    }

    if (reg.status != RegStatus.awaitingPayment) {
      return Text(
        'This registration is closed.',
        style: TextStyle(color: p.ink2, fontSize: 16),
      );
    }

    if (!_filled) {
      _phone.text = normalizeCameroonPhone(reg.phone)?.substring(3) ?? reg.phone;
      _filled = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pay for your course', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.softBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  reg.courseTitle,
                  style: TextStyle(
                    color: p.softInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                formatXaf(reg.feeXaf),
                style: TextStyle(
                  color: p.softInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_stage == _Stage.waiting)
          _waiting(context, reg)
        else
          _form_(context, reg),
      ],
    );
  }

  Widget _form_(BuildContext context, MyRegistration reg) {
    final p = context.palette;
    final hint = operatorHint(normalizeCameroonPhone(_phone.text) ?? '');
    return SectionCard(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stage == _Stage.failed) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.dangerBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _failure == null || _failure!.isEmpty
                      ? 'The payment did not go through. You were not charged. '
                          'Check your balance and try again.'
                      : 'The payment did not go through: $_failure',
                  style: TextStyle(color: p.danger, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppTextField(
              label: 'Mobile money number',
              helper: hint ?? 'MTN or Orange, for example 677 12 34 56',
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (v) => normalizeCameroonPhone(v ?? '') == null
                  ? 'Enter a valid MTN or Orange number'
                  : null,
              onSubmitted: (_) => _busy ? null : _start(reg),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Pay ${formatXaf(reg.feeXaf)}',
              loading: _busy,
              onPressed: _busy ? null : () => _start(reg),
            ),
            const SizedBox(height: 6),
            Text(
              'You will get a prompt on your phone. Enter your PIN to '
              'approve. We never see your PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.ink2, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 6),
            AppButton(
              label: 'Pay in cash instead',
              style: AppButtonStyle.text,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Pay in cash'),
                  content: const Text(
                    'You can pay the administrator in cash. Once they record '
                    'your payment, you get access right away. Tell them your '
                    'name and the course.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
            AppButton(
              label: 'Cancel registration',
              style: AppButtonStyle.text,
              onPressed: () => _cancel(reg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waiting(BuildContext context, MyRegistration reg) {
    final p = context.palette;
    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 20),
          Text(
            'Check your phone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Approve the payment of ${formatXaf(reg.feeXaf)} by entering '
            'your PIN. This page updates by itself.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.ink2, fontSize: 15.5, height: 1.5),
          ),
          if (_ussd != null && _ussd!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No prompt? Dial $_ussd',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.ink2, fontSize: 14),
            ),
          ],
          if (_slow) ...[
            const SizedBox(height: 18),
            Text(
              'Taking long? If you already approved, check again. '
              'Otherwise you can start over.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.ink2, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'I approved it, check now',
              style: AppButtonStyle.outlined,
              loading: _checking,
              onPressed: _checking ? null : _checkNow,
            ),
            AppButton(
              label: 'Start over',
              style: AppButtonStyle.text,
              onPressed: () {
                _timer?.cancel();
                setState(() => _stage = _Stage.form);
              },
            ),
          ],
        ],
      ),
    );
  }
}