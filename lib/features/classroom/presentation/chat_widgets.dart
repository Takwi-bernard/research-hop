import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/web_audio.dart';
import '../../../core/utils/web_files.dart';
import '../../../shared/widgets/snack.dart';
import '../application/classroom_controller.dart';
import '../data/classroom_models.dart';

String _clock(DateTime time) {
  final t = time.toLocal();
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

String durationLabel(int? ms) {
  final total = ((ms ?? 0) / 1000).round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// One line in the conversation: a bubble, or a centred class notice.
class MessageTile extends StatelessWidget {
  const MessageTile({super.key, required this.message, required this.room});

  final ChatMessage message;
  final ClassRoomController room;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (message.kind == MessageKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${message.body ?? ''}  ·  ${_clock(message.createdAt)}',
              style: TextStyle(color: p.ink2, fontSize: 12.5),
            ),
          ),
        ),
      );
    }

    final mine = message.senderId == room.myId;
    final Color bubble;
    final Color ink;
    Border? border;
    if (mine) {
      bubble = p.accent;
      ink = p.accentInk;
    } else if (message.fromInstructor) {
      bubble = p.softBg;
      ink = p.softInk;
    } else {
      bubble = p.surface;
      ink = p.ink;
      border = Border.all(color: p.line);
    }

    final maxWidth = math.min(MediaQuery.sizeOf(context).width * 0.8, 520.0);
    final studentSender = !mine && !message.fromInstructor;
    final muted = room.mutedIds.contains(message.senderId);
    // Swipe left (or tap the ticks) to see who has read it. Senders see
    // their own messages; the instructor sees every message.
    final canInfo = message.state == SendState.sent &&
        message.kind != MessageKind.system &&
        (mine || room.isTeacher);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.fromInstructor)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.school_rounded,
                              size: 14, color: p.softInk),
                        ),
                      Flexible(
                        child: Text(
                          message.senderLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.ink2,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (message.privateToInstructor) ...[
                        const SizedBox(width: 6),
                        Text(
                          'private',
                          style: TextStyle(color: p.gold, fontSize: 12),
                        ),
                      ],
                      if (muted) ...[
                        const SizedBox(width: 6),
                        Text(
                          'muted',
                          style: TextStyle(color: p.danger, fontSize: 12),
                        ),
                      ],
                      if (room.isTeacher && studentSender)
                        SizedBox(
                          width: 30,
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            tooltip: 'Student options',
                            icon: Icon(Icons.more_horiz_rounded, color: p.ink2),
                            onSelected: (value) async {
                              final error = value == 'mute'
                                  ? await room.mute(message.senderId)
                                  : await room.unmute(message.senderId);
                              if (error != null && context.mounted) {
                                showAppSnack(context, error, error: true);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: muted ? 'unmute' : 'mute',
                                child: Text(
                                  muted ? 'Allow to write again' : 'Mute student',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              _SwipeToInfo(
                enabled: canInfo,
                onInfo: () => showMessageInfo(context, room, message),
                child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  color: bubble,
                  border: border,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _content(context, ink),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _clock(message.createdAt),
                            style: TextStyle(
                              color: ink.withValues(alpha: 0.7),
                              fontSize: 11.5,
                            ),
                          ),
                          if (mine) ...[
                            const SizedBox(width: 4),
                            InkResponse(
                              onTap: canInfo
                                  ? () => showMessageInfo(context, room, message)
                                  : null,
                              radius: 16,
                              child: ReadTicks(
                                state: message.state,
                                readCount: room.readersOf(message).length,
                                ink: ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
              if (mine && message.privateToInstructor)
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 6),
                  child: Text(
                    'Only the instructor can see this',
                    style: TextStyle(color: p.ink2, fontSize: 12),
                  ),
                ),
              if (message.state == SendState.sending &&
                  message.kind != MessageKind.text)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      value: message.progress > 0 && message.progress < 1
                          ? message.progress
                          : null,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              if (message.state == SendState.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Not sent',
                          style: TextStyle(color: p.danger, fontSize: 13)),
                      TextButton(
                        onPressed: () => room.retry(message),
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: () => room.discard(message),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Color ink) {
    switch (message.kind) {
      case MessageKind.image:
        return _ImageContent(message: message, room: room, ink: ink);
      case MessageKind.audio:
        return _AudioContent(message: message, room: room, ink: ink);
      case MessageKind.file:
        return _FileContent(message: message, room: room, ink: ink);
      case MessageKind.text:
      case MessageKind.system:
        return SelectableText(
          message.body ?? '',
          style: TextStyle(color: ink, fontSize: 15.5, height: 1.4),
        );
    }
  }
}

/// Pictures wait for a tap, so people on a small data plan choose to
/// download them.
class _ImageContent extends StatefulWidget {
  const _ImageContent({
    required this.message,
    required this.room,
    required this.ink,
  });

  final ChatMessage message;
  final ClassRoomController room;
  final Color ink;

  @override
  State<_ImageContent> createState() => _ImageContentState();
}

class _ImageContentState extends State<_ImageContent> {
  String? _url;
  bool _loading = false;

  Future<void> _load() async {
    final path = widget.message.mediaPath;
    if (path == null || _loading) return;
    setState(() => _loading = true);
    try {
      final url = await widget.room.repo.mediaUrl(path);
      if (mounted) setState(() => _url = url);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final bytes = message.pendingBytes;
    if (message.mediaPath == null && bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 220, fit: BoxFit.cover),
      );
    }
    if (_url != null) {
      return GestureDetector(
        onTap: () => openInNewTab(_url!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _url!,
            width: 240,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(
              'The picture could not load.',
              style: TextStyle(color: widget.ink),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    width: 240,
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: _load,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 200,
        child: Row(
          children: [
            _loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: widget.ink,
                    ),
                  )
                : Icon(Icons.image_outlined, color: widget.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap to view photo\n${formatBytes(message.mediaSize)}',
                style: TextStyle(color: widget.ink, fontSize: 14, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioContent extends StatefulWidget {
  const _AudioContent({
    required this.message,
    required this.room,
    required this.ink,
  });

  final ChatMessage message;
  final ClassRoomController room;
  final Color ink;

  @override
  State<_AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends State<_AudioContent> {
  WebAudioPlayer? _player;
  bool _loading = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final path = widget.message.mediaPath;
    if (path == null || _loading) return;
    var player = _player;
    if (player == null) {
      setState(() => _loading = true);
      try {
        final url = await widget.room.repo.mediaUrl(path);
        player = WebAudioPlayer(url)..onChange = () {
            if (mounted) setState(() {});
          };
        _player = player;
      } catch (error) {
        if (mounted) showAppSnack(context, friendlyError(error), error: true);
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    await player.toggle();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final player = _player;
    final playing = player?.playing ?? false;
    final total = message.mediaDurationMs ?? 0;
    final position = player?.positionMs ?? 0;
    final fraction = total <= 0 ? 0.0 : (position / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          IconButton(
            onPressed: message.mediaPath == null ? null : _toggle,
            style: IconButton.styleFrom(
              backgroundColor: widget.ink.withValues(alpha: 0.14),
              foregroundColor: widget.ink,
            ),
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: widget.ink,
                    ),
                  )
                : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: playing || position > 0 ? fraction : 0,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                  color: widget.ink,
                  backgroundColor: widget.ink.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 4),
                Text(
                  player?.failed == true
                      ? 'Could not play'
                      : 'Voice note  ·  ${durationLabel(total)}',
                  style: TextStyle(color: widget.ink, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileContent extends StatefulWidget {
  const _FileContent({
    required this.message,
    required this.room,
    required this.ink,
  });

  final ChatMessage message;
  final ClassRoomController room;
  final Color ink;

  @override
  State<_FileContent> createState() => _FileContentState();
}

class _FileContentState extends State<_FileContent> {
  bool _loading = false;

  Future<void> _open() async {
    final path = widget.message.mediaPath;
    if (path == null || _loading) return;
    setState(() => _loading = true);
    try {
      final url = await widget.room.repo.mediaUrl(path);
      openInNewTab(url);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return InkWell(
      onTap: message.mediaPath == null ? null : _open,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_outlined, color: widget.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body ?? 'File',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  Text(
                    formatBytes(message.mediaSize),
                    style: TextStyle(
                      color: widget.ink.withValues(alpha: 0.75),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: widget.ink,
                    ),
                  )
                : Icon(Icons.download_rounded, color: widget.ink),
          ],
        ),
      ),
    );
  }
}


/// Sending clock, one grey tick (delivered to the class), two coloured
/// ticks (someone has read it).
class ReadTicks extends StatelessWidget {
  const ReadTicks({
    super.key,
    required this.state,
    required this.readCount,
    required this.ink,
  });

  final SendState state;
  final int readCount;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final readColor = dark ? const Color(0xFF0B63B5) : const Color(0xFF8FD6FF);
    final (icon, color) = switch (state) {
      SendState.sending => (Icons.schedule_rounded, ink.withValues(alpha: 0.65)),
      SendState.failed => (Icons.error_outline_rounded, const Color(0xFFFF8A80)),
      SendState.sent => readCount > 0
          ? (Icons.done_all_rounded, readColor)
          : (Icons.done_rounded, ink.withValues(alpha: 0.65)),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(icon, key: ValueKey('$state-${readCount > 0}'), size: 16, color: color),
    );
  }
}

/// Lets a bubble be pulled to the left; letting go past a threshold opens
/// the "Seen by" sheet, like in a messaging app.
class _SwipeToInfo extends StatefulWidget {
  const _SwipeToInfo({
    required this.enabled,
    required this.onInfo,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onInfo;
  final Widget child;

  @override
  State<_SwipeToInfo> createState() => _SwipeToInfoState();
}

class _SwipeToInfoState extends State<_SwipeToInfo> {
  double _dx = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final p = context.palette;
    final progress = (-_dx / 56).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (details) {
        setState(() => _dx = (_dx + details.delta.dx).clamp(-84.0, 0.0));
      },
      onHorizontalDragEnd: (_) {
        final open = _dx <= -56;
        setState(() {
          _dragging = false;
          _dx = 0;
        });
        if (open) widget.onInfo();
      },
      onHorizontalDragCancel: () => setState(() {
        _dragging = false;
        _dx = 0;
      }),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 0,
            child: Opacity(
              opacity: progress,
              child: Icon(Icons.visibility_outlined, color: p.ink2, size: 20),
            ),
          ),
          AnimatedContainer(
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx * 0.6, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// "Seen by" sheet for one message.
Future<void> showMessageInfo(
  BuildContext context,
  ClassRoomController room,
  ChatMessage message,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MessageInfoSheet(room: room, message: message),
  );
}

class _MessageInfoSheet extends StatelessWidget {
  const _MessageInfoSheet({required this.room, required this.message});

  final ClassRoomController room;
  final ChatMessage message;

  String get _preview {
    switch (message.kind) {
      case MessageKind.image:
        return 'Photo';
      case MessageKind.audio:
        return 'Voice note  ${durationLabel(message.mediaDurationMs)}';
      case MessageKind.file:
        return message.body ?? 'File';
      case MessageKind.text:
      case MessageKind.system:
        return message.body ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final readers = room.readersOf(message)
          ..sort((a, b) => a.readAt.compareTo(b.readAt));
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text('Message info',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, height: 1.4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sent at ${_clock(message.createdAt)}',
                  style: TextStyle(color: p.ink2, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      readers.isEmpty
                          ? Icons.done_rounded
                          : Icons.done_all_rounded,
                      size: 20,
                      color: readers.isEmpty ? p.ink2 : const Color(0xFF2B8FD6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      readers.isEmpty
                          ? 'Not seen yet'
                          : 'Seen by ${readers.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final r in readers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: p.softBg,
                      child: Text(
                        r.label.isEmpty ? '?' : r.label[0].toUpperCase(),
                        style: TextStyle(
                          color: p.softInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(r.label),
                    trailing: Text(
                      _clock(r.readAt),
                      style: TextStyle(color: p.ink2, fontSize: 13),
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

/// "Amina is typing…" with three bouncing dots.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.names});

  final List<String> names;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _label {
    final n = widget.names.toSet().toList();
    if (n.isEmpty) return '';
    if (n.length == 1) return '${n.first} is typing';
    if (n.length == 2) return '${n[0]} and ${n[1]} are typing';
    return '${n[0]}, ${n[1]} and ${n.length - 2} more are typing';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.bottomLeft,
      child: widget.names.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.accent.withValues(
                                alpha: 0.35 +
                                    0.65 *
                                        math.max(
                                          0,
                                          math.sin(
                                            (_c.value * 2 * math.pi) - i * 0.9,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.ink2,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
