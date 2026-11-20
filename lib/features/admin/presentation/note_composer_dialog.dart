import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/web_files.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

const noteFileTypes = <String, String>{
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};

const _maxFileBytes = 50 * 1024 * 1024;

/// One form for a course note: a title, the text, and (optionally) one file
/// that belongs to it. Shows a progress bar while the file uploads.
class NoteComposerDialog extends ConsumerStatefulWidget {
  const NoteComposerDialog({
    super.key,
    required this.courseId,
    required this.nextPosition,
    this.note,
  });

  final String courseId;
  final int nextPosition;
  final CourseNote? note;

  @override
  ConsumerState<NoteComposerDialog> createState() => _NoteComposerDialogState();
}

class _NoteComposerDialogState extends ConsumerState<NoteComposerDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _text =
      TextEditingController(text: widget.note?.description ?? '');

  PickedFile? _file;
  String? _noteId;
  String? _error;
  bool _busy = false;
  double _progress = 0;
  int _sent = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final picked = await pickFile(extensions: noteFileTypes.keys.toList());
    if (picked == null) return;
    if (picked.bytes.length > _maxFileBytes) {
      setState(() => _error = 'Files can be at most 50 MB.');
      return;
    }
    if (!noteFileTypes.containsKey(picked.extension)) {
      setState(() => _error = 'That file type is not allowed.');
      return;
    }
    setState(() {
      _file = picked;
      _error = null;
      if (_title.text.trim().isEmpty) {
        final dot = picked.name.lastIndexOf('.');
        _title.text = dot > 0 ? picked.name.substring(0, dot) : picked.name;
      }
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
      _sent = 0;
      _total = 0;
    });
    final repo = ref.read(adminRepositoryProvider);
    try {
      _noteId = await repo.saveNote(
        courseId: widget.courseId,
        noteId: _noteId,
        title: _title.text.trim(),
        description: _text.text.trim(),
        position: widget.nextPosition,
      );

      final file = _file;
      if (file != null) {
        try {
          await repo.uploadMaterial(
            courseId: widget.courseId,
            noteId: _noteId!,
            title: file.name,
            fileName: file.name,
            bytes: file.bytes,
            mimeType: noteFileTypes[file.extension]!,
            onProgress: (fraction, sent, total) {
              if (!mounted) return;
              setState(() {
                _progress = fraction;
                _sent = sent;
                _total = total;
              });
            },
          );
        } catch (error) {
          if (mounted) {
            setState(() {
              _error = 'Your note is saved, but the file did not upload. '
                  '${friendlyError(error)}';
              _busy = false;
            });
          }
          return;
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final editing = widget.note != null;
    final file = _file;
    final uploading = _busy && file != null && _total > 0;

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: p.surface,
        title: Text(editing ? 'Edit note' : 'Add notes or a file'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    autofocus: !editing,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'For example: Week 1 - Introduction',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Please give this a title'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _text,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 9,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'What students should read or know',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Attached file (optional)',
                    style: TextStyle(color: p.ink2, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (file == null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _choose,
                      icon: const Icon(Icons.attach_file_rounded, size: 20),
                      label: const Text('Choose a file'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      decoration: BoxDecoration(
                        color: p.surface2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, color: p.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formatBytes(file.bytes.length),
                                  style: TextStyle(color: p.ink2, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove file',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _file = null),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'PDF, Word, PowerPoint or an image, up to 50 MB.',
                    style: TextStyle(color: p.ink2, fontSize: 13),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: uploading ? _progress : null,
                        minHeight: 10,
                        backgroundColor: p.surface2,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      uploading
                          ? 'Uploading ${(_progress * 100).round()}%  ·  '
                              '${formatBytes(_sent)} of ${formatBytes(_total)}'
                          : 'Saving...',
                      style: TextStyle(color: p.ink2, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Please keep this window open until it finishes.',
                      style: TextStyle(color: p.ink2, fontSize: 13),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: p.danger, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(_noteId != null && widget.note == null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              file == null
                  ? 'Save'
                  : (_noteId != null && _error != null ? 'Retry upload' : 'Save and upload'),
            ),
          ),
        ],
      ),
    );
  }
}
