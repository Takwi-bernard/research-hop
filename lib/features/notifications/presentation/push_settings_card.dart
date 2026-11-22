import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/web_push.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../data/push_repository.dart';

/// Lets a person turn browser notifications on or off for this device.
/// With [compact] it is a small prompt that disappears once notifications
/// are on (or cannot be used).
class PushSettingsCard extends ConsumerStatefulWidget {
  const PushSettingsCard({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<PushSettingsCard> createState() => _PushSettingsCardState();
}

class _PushSettingsCardState extends ConsumerState<PushSettingsCard> {
  PushStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await readPushStatus();
    if (!mounted) return;
    setState(() => _status = status);
    // If this browser already allows notifications, make sure they belong to
    // the person who is signed in now (the browser may be shared).
    final data = status.subscription;
    if (status.enabled && data != null) {
      try {
        await ref.read(pushRepositoryProvider).save(data);
      } catch (_) {}
    }
  }

  Future<void> _enable() async {
    final key = Env.vapidPublicKey;
    if (key.isEmpty) {
      showAppSnack(context, 'Notifications are not set up yet.', error: true);
      return;
    }
    setState(() => _busy = true);
    // First await: the browser must see the permission request as a reaction
    // to the tap.
    final result = await enablePush(key);
    if (!mounted) return;
    try {
      final data = result.data;
      if (data != null) {
        await ref.read(pushRepositoryProvider).save(data);
        showAppSnack(context, 'Notifications are on for this device.');
      } else if (result.problem == 'denied') {
        showAppSnack(
          context,
          'Notifications were not allowed. You can change this in the browser settings.',
          error: true,
        );
      } else if (result.problem == 'unsupported') {
        showAppSnack(
          context,
          'This browser cannot show notifications.',
          error: true,
        );
      } else {
        showAppSnack(
          context,
          'Could not turn notifications on. Please try again.',
          error: true,
        );
      }
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    final endpoint = await disablePush();
    if (endpoint != null) {
      try {
        await ref.read(pushRepositoryProvider).remove(endpoint);
      } catch (_) {}
    }
    await _load();
    if (mounted) {
      setState(() => _busy = false);
      showAppSnack(context, 'Notifications are off for this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final status = _status;
    if (status == null) return const SizedBox.shrink();

    if (widget.compact) {
      // Only invite when it is possible and not yet decided.
      if (!status.supported ||
          status.denied ||
          status.enabled ||
          Env.vapidPublicKey.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.softBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Text(
                  'Get class reminders and answers even when this page is closed.',
                  style: TextStyle(
                    color: p.softInk,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              AppButton(
                label: 'Turn on notifications',
                expand: false,
                loading: _busy,
                leading: const Icon(Icons.notifications_active_outlined, size: 18),
                onPressed: _enable,
              ),
            ],
          ),
        ),
      );
    }

    final String text;
    Widget? action;
    if (Env.vapidPublicKey.isEmpty) {
      text = 'Notifications are not set up on this site yet.';
    } else if (!status.supported) {
      text = 'This browser cannot show notifications. On an iPhone, add '
          'Research Hop to the Home Screen first, then open it from there.';
    } else if (status.denied) {
      text = 'Notifications are blocked. Click the lock icon next to the '
          'address, allow notifications, then reload this page.';
    } else if (status.enabled) {
      text = 'On for this device. You will see class reminders, answers to '
          'your requests and announcements.';
      action = AppButton(
        label: 'Turn off',
        style: AppButtonStyle.outlined,
        expand: false,
        loading: _busy,
        onPressed: _disable,
      );
    } else {
      text = 'Get class reminders and answers even when this page is closed.';
      action = AppButton(
        label: 'Turn on',
        expand: false,
        loading: _busy,
        leading: const Icon(Icons.notifications_active_outlined, size: 18),
        onPressed: _enable,
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications on this device',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    );
  }
}
