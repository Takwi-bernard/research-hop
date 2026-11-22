import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/upload_exception.dart';
import '../../../core/utils/web_audio.dart';
import '../../../core/utils/web_files.dart';
import '../../../shared/widgets/snack.dart';
import '../application/classroom_controller.dart';
import '../data/classroom_models.dart';
import 'chat_widgets.dart';

const _maxVoiceSeconds = 120;
const _maxFileBytes = 10 * 1024 * 1024;

/// The bottom bar of the class room. What it shows depends on the class
/// state, the chat mode and whether the person is muted.
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.room});

  final ClassRoomController room;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _hadFloor = false;
  final _recorder = VoiceRecorder();
  Timer? _tick;
  int _seconds = 0;
  bool _recording = false;

  ClassRoomController get room => widget.room;

  @override
  void dispose() {
    _tick?.cancel();
    _recorder.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (mounted) showAppSnack(context, message, error: true);
  }

  void _send() {
    final value = _text.text;
    if (value.trim().isEmpty) return;
    _text.clear();
    room.sendText(value);
  }

  Future<void> _pickImage() async {
    try {
      final file = await pickFile(extensions: const ['jpg', 'jpeg', 'png', 'webp']);
      if (file == null) return;
      final small = await compressImage(file.bytes, maxSide: 1280, quality: 0.78);
      await room.sendMedia(
        kind: MessageKind.image,
        bytes: small,
        mimeType: 'image/jpeg',
        extension: 'jpg',
        name: file.name,
      );
    } on UploadException catch (error) {
      _toast(error.message);
    }
  }

  Future<void> _pickFile() async {
    final file = await pickFile(extensions: const ['pdf']);
    if (file == null) return;
    if (file.bytes.length > _maxFileBytes) {
      _toast('Files can be up to 10 MB.');
      return;
    }
    await room.sendMedia(
      kind: MessageKind.file,
      bytes: file.bytes,
      mimeType: 'application/pdf',
      extension: 'pdf',
      name: file.name,
    );
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.start();
    } on UploadException catch (error) {
      _toast(error.message);
      return;
    }
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= _maxVoiceSeconds) _finishRecording();
    });
  }

  void _cancelRecording() {
    _tick?.cancel();
    _recorder.cancel();
    setState(() => _recording = false);
  }

  Future<void> _finishRecording() async {
    _tick?.cancel();
    if (!_recording) return;
    setState(() => _recording = false);
    final audio = await _recorder.stop();
    if (audio == null) {
      _toast('Nothing was recorded. Please try again.');
      return;
    }
    if (audio.durationMs < 700) return;
    if (audio.bytes.length > _maxFileBytes) {
      _toast('That voice note is too long.');
      return;
    }
    await room.sendMedia(
      kind: MessageKind.audio,
      bytes: audio.bytes,
      mimeType: audio.mimeType,
      extension: audio.extension,
      name: 'voice',
      durationMs: audio.durationMs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = room.session;
    if (session == null) return const SizedBox.shrink();

    // When the instructor gives this student the floor, the keyboard opens.
    if (room.hasFloor && !_hadFloor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
    _hadFloor = room.hasFloor;

    Widget body;
    if (session.scheduled) {
      body = _banner(
        p,
        room.isTeacher
            ? 'Start the class when you are ready. Students can write only after it starts.'
            : 'This class has not started yet. The chat opens when your instructor starts it.',
      );
    } else if (session.status == ClassStatus.cancelled) {
      body = _banner(p, 'This class was cancelled.');
    } else if (session.status == ClassStatus.ended) {
      body = _banner(p, 'This class has ended. You can still read the conversation.');
    } else if (!room.isTeacher && room.iAmMuted) {
      body = _banner(p, 'Your instructor has muted you for now. You can still read the chat.');
    } else if (!room.canWrite) {
      body = _lockedStudent(p);
    } else {
      body = _inputRow(p, session);
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(top: false, child: body),
    );
  }

  Widget _banner(AppPalette p, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: p.ink2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _handButton(AppPalette p) {
    final up = room.myHandUp;
    return OutlinedButton.icon(
      onPressed: room.busy
          ? null
          : () async {
              final error = await room.toggleHand();
              if (error != null) _toast(error);
            },
      icon: Icon(
        up ? Icons.back_hand_rounded : Icons.back_hand_outlined,
        size: 18,
        color: up ? p.gold : null,
      ),
      label: Text(up ? 'Hand raised  ·  lower' : 'Raise hand'),
    );
  }

  Widget _lockedStudent(AppPalette p) {
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: p.ink2, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Chat is locked. Raise your hand to ask a question.',
            style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.35),
          ),
        ),
        const SizedBox(width: 10),
        _handButton(p),
      ],
    );
  }

  Widget _inputRow(AppPalette p, ClassSession session) {
    if (_recording) {
      return Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            onPressed: _cancelRecording,
            icon: Icon(Icons.delete_outline_rounded, color: p.danger),
          ),
          Icon(Icons.fiber_manual_record_rounded, color: p.danger, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording  ${durationLabel(_seconds * 1000)}',
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton.icon(
            onPressed: _finishRecording,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send'),
          ),
        ],
      );
    }

    final privateReply = !room.isTeacher && session.chatMode == ChatMode.teacherOnly;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (privateReply)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.visibility_off_outlined, size: 16, color: p.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only the instructor will see what you write.',
                    style: TextStyle(color: p.ink2, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (room.canSendMedia) ...[
              IconButton(
                tooltip: 'Photo',
                onPressed: _pickImage,
                icon: Icon(Icons.image_outlined, color: p.ink2),
              ),
              IconButton(
                tooltip: 'PDF file',
                onPressed: _pickFile,
                icon: Icon(Icons.attach_file_rounded, color: p.ink2),
              ),
            ],
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: privateReply ? 'Write to the instructor' : 'Write a message',
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                  if (value.trim().isNotEmpty) room.notifyTyping();
                },
              ),
            ),
            const SizedBox(width: 6),
            if (_text.text.trim().isEmpty && room.canSendMedia)
              IconButton.filled(
                tooltip: 'Record a voice note',
                onPressed: _startRecording,
                icon: const Icon(Icons.mic_rounded),
              )
            else
              IconButton.filled(
                tooltip: 'Send',
                onPressed: _text.text.trim().isEmpty ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
          ],
        ),
        if (!room.isTeacher && !room.hasFloor)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: room.busy
                    ? null
                    : () async {
                        final error = await room.toggleHand();
                        if (error != null) _toast(error);
                      },
                icon: Icon(
                  room.myHandUp
                      ? Icons.back_hand_rounded
                      : Icons.back_hand_outlined,
                  size: 18,
                ),
                label: Text(room.myHandUp ? 'Lower hand' : 'Raise hand'),
              ),
            ),
          ),
      ],
    );
  }
}
