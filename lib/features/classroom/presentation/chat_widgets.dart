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
              Container(
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
                      child: Text(
                        _clock(message.createdAt),
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.7),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
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
