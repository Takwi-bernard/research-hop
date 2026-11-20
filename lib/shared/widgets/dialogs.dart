import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool danger = false,
}) async {
  final p = context.palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: p.surface,
      title: Text(title),
      content: Text(message, style: TextStyle(color: p.ink2, height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: p.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class DialogField {
  const DialogField({
    required this.label,
    this.hint,
    this.initial = '',
    this.maxLines = 1,
    this.required = false,
  });

  final String label;
  final String? hint;
  final String initial;
  final int maxLines;
  final bool required;
}

/// A dialog with one or more text boxes. Returns the texts, or null if closed.
Future<List<String>?> showFieldsDialog(
  BuildContext context, {
  required String title,
  required List<DialogField> fields,
  String confirmLabel = 'Save',
  String? message,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FieldsDialog(
      title: title,
      fields: fields,
      confirmLabel: confirmLabel,
      message: message,
    ),
  );
}

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({
    required this.title,
    required this.fields,
    required this.confirmLabel,
    this.message,
  });

  final String title;
  final List<DialogField> fields;
  final String confirmLabel;
  final String? message;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop([for (final c in _controllers) c.text.trim()]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      backgroundColor: p.surface,
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message != null) ...[
                  Text(
                    widget.message!,
                    style: TextStyle(color: p.ink2, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                ],
                for (var i = 0; i < widget.fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  TextFormField(
                    controller: _controllers[i],
                    autofocus: i == 0,
                    minLines: 1,
                    maxLines: widget.fields[i].maxLines,
                    decoration: InputDecoration(
                      labelText: widget.fields[i].label,
                      hintText: widget.fields[i].hint,
                    ),
                    validator: widget.fields[i].required
                        ? (value) => (value ?? '').trim().isEmpty
                            ? 'Please fill this in'
                            : null
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
