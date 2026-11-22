import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../core/supabase/providers.dart';
import '../application/classroom_controller.dart';
import '../application/classroom_providers.dart';
import '../data/classroom_models.dart';
import 'chat_composer.dart';
import 'chat_widgets.dart';

/// The live class: header, instructor controls, conversation and composer.
/// Used by teachers and by enrolled students.
class ClassRoomPage extends ConsumerStatefulWidget {
  const ClassRoomPage({
    super.key,
    required this.sessionId,
    required this.isTeacher,
  });

  final String sessionId;
  final bool isTeacher;

  @override
  ConsumerState<ClassRoomPage> createState() => _ClassRoomPageState();
}

class _ClassRoomPageState extends ConsumerState<ClassRoomPage> {
  late final ClassRoomController _room;

  @override
  void initState() {
    super.initState();
    _room = ClassRoomController(
      client: ref.read(supabaseClientProvider),
      repo: ref.read(classroomRepositoryProvider),
      sessionId: widget.sessionId,
      isTeacher: widget.isTeacher,
    )..addListener(_showSendProblem);
    _room.start();
  }

  void _showSendProblem() {
    final text = _room.lastError;
    if (text == null) return;
    _room.lastError = null;
    if (mounted) showAppSnack(context, text, error: true);
  }

  @override
  void dispose() {
    _room
      ..removeListener(_showSendProblem)
      ..dispose();
    super.dispose();
  }

  void _back() =>
      context.go(widget.isTeacher ? '/teacher/classes' : '/student');

  void _toast(String message) {
    if (mounted) showAppSnack(context, message, error: true);
  }

  Future<void> _run(Future<String?> Function() action) async {
    final error = await action();
    if (error != null && mounted) showAppSnack(context, error, error: true);
  }

  Future<void> _end() async {
    final ok = await confirmDialog(
      context,
      title: 'End this class?',
      message: 'The chat will close for everyone. Students can still read it.',
      confirmLabel: 'End class',
      danger: true,
    );
    if (ok) await _run(_room.endClass);
  }

  void _showHands() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HandsSheet(room: _room),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: _room,
      builder: (context, _) {
        if (_room.loading) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }
        final session = _room.session;
        if (session == null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: p.ink2, size: 32),
              const SizedBox(height: 12),
              Text(
                friendlyError(_room.loadError ?? 'error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.ink2),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  AppButton(
                    label: 'Try again',
                    expand: false,
                    onPressed: _room.retryLoad,
                  ),
                  AppButton(
                    label: 'Back',
                    style: AppButtonStyle.outlined,
                    expand: false,
                    onPressed: _back,
                  ),
                ],
              ),
            ],
          );
        }

        final items = _room.messages.reversed.toList();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                _Header(
                  session: session,
                  reconnecting: !_room.connected && !session.finished,
                  onBack: _back,
                ),
                if (widget.isTeacher && !session.finished)
                  _TeacherBar(
                    room: _room,
                    session: session,
                    onStart: () => _run(_room.startClass),
                    onEnd: _end,
                    onHands: _showHands,
                    onMode: (mode, media) => _run(() => _room.setMode(mode, media)),
                  ),
                if (widget.isTeacher && session.live)
                  _HandQueue(room: _room, onMore: _showHands, onError: _toast),
                Expanded(
                  child: items.isEmpty
                      ? EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'No messages yet',
                          message: session.live
                              ? 'Say hello to get the class started.'
                              : 'Messages will appear here once the class starts.',
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          itemCount: items.length,
                          itemBuilder: (context, index) => MessageTile(
                            key: ValueKey(items[index].clientId),
                            message: items[index],
                            room: _room,
                          ),
                        ),
                ),
                TypingIndicator(names: _room.typingNames),
                if (!widget.isTeacher && session.live)
                  _StudentHandNote(room: _room, onError: _toast),
                ChatComposer(room: _room),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.reconnecting,
    required this.onBack,
  });

  final ClassSession session;
  final bool reconnecting;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (label, tone) = switch (session.status) {
      ClassStatus.live => ('Live now', ChipTone.bad),
      ClassStatus.scheduled => ('Scheduled', ChipTone.warn),
      ClassStatus.ended => ('Ended', ChipTone.neutral),
      ClassStatus.cancelled => ('Cancelled', ChipTone.neutral),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  reconnecting
                      ? 'Reconnecting…'
                      : '${session.courseTitle}  ·  ${formatDateTime(session.scheduledAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reconnecting ? p.gold : p.ink2,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label, tone: tone),
        ],
      ),
    );
  }
}

class _TeacherBar extends StatelessWidget {
  const _TeacherBar({
    required this.room,
    required this.session,
    required this.onStart,
    required this.onEnd,
    required this.onHands,
    required this.onMode,
  });

  final ClassRoomController room;
  final ClassSession session;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onHands;
  final void Function(ChatMode mode, bool media) onMode;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (session.scheduled) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Start class',
            expand: false,
            loading: room.busy,
            leading: const Icon(Icons.play_arrow_rounded, size: 20),
            onPressed: onStart,
          ),
        ),
      );
    }

    final mode = session.chatMode;
    final help = switch (mode) {
      ChatMode.locked => 'Only you can write. Students can raise a hand.',
      ChatMode.teacherOnly =>
        'Students can reply, but only you see their messages.',
      ChatMode.open => 'Everyone in the class can write and read.',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: p.surface2,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<ChatMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ChatMode.locked,
                    label: Text('Locked'),
                    icon: Icon(Icons.lock_outline_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ChatMode.teacherOnly,
                    label: Text('Replies'),
                    icon: Icon(Icons.visibility_off_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ChatMode.open,
                    label: Text('Open'),
                    icon: Icon(Icons.forum_outlined, size: 16),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: room.busy
                    ? null
                    : (value) =>
                        onMode(value.first, session.studentsCanSendMedia),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: session.studentsCanSendMedia,
                    onChanged: room.busy || mode == ChatMode.locked
                        ? null
                        : (value) => onMode(mode, value),
                  ),
                  const Text('Photos, voice, files'),
                ],
              ),
              Badge(
                isLabelVisible: room.waitingHands.isNotEmpty,
                label: Text('${room.waitingHands.length}'),
                child: OutlinedButton.icon(
                  onPressed: onHands,
                  icon: const Icon(Icons.back_hand_outlined, size: 18),
                  label: const Text('Hands and muted'),
                ),
              ),
              TextButton(
                onPressed: room.busy ? null : onEnd,
                style: TextButton.styleFrom(foregroundColor: p.danger),
                child: const Text('End class'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(help, style: TextStyle(color: p.ink2, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _HandsSheet extends StatelessWidget {
  const _HandsSheet({required this.room});

  final ClassRoomController room;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        // Names of muted students come from what they wrote earlier.
        final names = <String, String>{
          for (final m in room.messages)
            if (m.senderRole == 'student') m.senderId: m.senderLabel,
          for (final h in room.hands) h.studentId: h.label,
        };
        final muted = room.mutedIds.toList();

        Future<void> act(Future<String?> Function() action) async {
          final error = await action();
          if (error != null && context.mounted) {
            showAppSnack(context, error, error: true);
          }
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text('Raised hands',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (room.hands.isEmpty)
                  Text('Nobody has raised a hand.',
                      style: TextStyle(color: p.ink2))
                else
                  for (final hand in room.hands)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        hand.hasFloor
                            ? Icons.record_voice_over_rounded
                            : Icons.back_hand_rounded,
                        color: hand.hasFloor ? p.accent : p.gold,
                      ),
                      title: Text(hand.label),
                      subtitle: Text(
                        hand.hasFloor
                            ? 'Has the floor'
                            : timeAgo(hand.createdAt),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (hand.hasFloor)
                            TextButton(
                              onPressed: room.busy
                                  ? null
                                  : () => act(() => room.endFloor(hand)),
                              child: const Text('Take back'),
                            )
                          else ...[
                            FilledButton.tonal(
                              onPressed: room.busy
                                  ? null
                                  : () => act(() => room.giveFloor(hand)),
                              child: const Text('Give floor'),
                            ),
                            TextButton(
                              onPressed: room.busy
                                  ? null
                                  : () => act(() => room.deferHand(hand)),
                              child: const Text('Later'),
                            ),
                          ],
                          TextButton(
                            onPressed: room.busy
                                ? null
                                : () => act(() => room.mute(hand.studentId)),
                            style: TextButton.styleFrom(
                              foregroundColor: p.danger,
                            ),
                            child: const Text('Mute'),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 18),
                Text('Muted students',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (muted.isEmpty)
                  Text('Nobody is muted.', style: TextStyle(color: p.ink2))
                else
                  for (final id in muted)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.mic_off_outlined, color: p.danger),
                      title: Text(names[id] ?? 'Student'),
                      trailing: TextButton(
                        onPressed:
                            room.busy ? null : () => act(() => room.unmute(id)),
                        child: const Text('Allow'),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Instructor view: the student who has the floor, and the next raised hand
/// with the two answers the instructor can give.
class _HandQueue extends StatelessWidget {
  const _HandQueue({
    required this.room,
    required this.onMore,
    required this.onError,
  });

  final ClassRoomController room;
  final VoidCallback onMore;
  final void Function(String message) onError;

  Future<void> _act(Future<String?> Function() action) async {
    final error = await action();
    if (error != null) onError(error);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final holder = room.floorHolder;
    final waiting = room.waitingHands;
    final next = waiting.isEmpty ? null : waiting.first;

    final cards = <Widget>[
      if (holder != null)
        Container(
          key: ValueKey('floor-${holder.id}'),
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: p.softBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: p.softInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${holder.label} has the floor',
                  style: TextStyle(
                    color: p.softInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    room.busy ? null : () => _act(() => room.endFloor(holder)),
                child: const Text('Take back'),
              ),
            ],
          ),
        ),
      if (next != null)
        Container(
          key: ValueKey('hand-${next.id}'),
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.gold, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.back_hand_rounded, color: p.gold),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 360),
                child: Text(
                  '${next.label} raised a hand'
                  '${waiting.length > 1 ? '  ·  +${waiting.length - 1} more' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton(
                onPressed:
                    room.busy ? null : () => _act(() => room.giveFloor(next)),
                child: const Text('Give the floor'),
              ),
              OutlinedButton(
                onPressed:
                    room.busy ? null : () => _act(() => room.deferHand(next)),
                child: const Text('Later'),
              ),
              if (waiting.length > 1)
                TextButton(onPressed: onMore, child: const Text('See all')),
            ],
          ),
        ),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: cards.isEmpty
            ? const SizedBox(key: ValueKey('none'), width: double.infinity)
            : Column(
                key: ValueKey(
                  '${holder?.id}-${next?.id}-${waiting.length}',
                ),
                children: cards,
              ),
      ),
    );
  }
}

/// Student view: a clear message once the instructor answers a raised hand.
class _StudentHandNote extends StatelessWidget {
  const _StudentHandNote({required this.room, required this.onError});

  final ClassRoomController room;
  final void Function(String message) onError;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hand = room.myHand;
    Widget? card;
    String key = 'none';

    if (room.hasFloor && hand != null) {
      key = 'floor-${hand.id}';
      card = Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: p.softBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.record_voice_over_rounded, color: p.softInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'The floor is yours. Type your question for the class.',
                style: TextStyle(
                  color: p.softInk,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              onPressed: room.busy
                  ? null
                  : () async {
                      final error = await room.endFloor(hand);
                      if (error != null) onError(error);
                    },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else if (room.showLaterNote && hand != null) {
      key = 'later-${hand.id}';
      card = Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: p.surface2,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: p.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your instructor saw your hand and will get to you later. '
                'Please keep listening.',
                style: TextStyle(color: p.ink, height: 1.3),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: room.dismissLaterNote,
              icon: Icon(Icons.close_rounded, color: p.ink2, size: 20),
            ),
          ],
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: card == null
            ? const SizedBox(key: ValueKey('none'), width: double.infinity)
            : KeyedSubtree(key: ValueKey(key), child: card),
      ),
    );
  }
}
