import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/snack.dart';
import '../../classroom/application/classroom_providers.dart';
import '../../classroom/data/classroom_models.dart';
import '../application/teacher_providers.dart';
import '../data/teacher_repository.dart';

/// Schedules a new class, or edits one that has not started.
/// Returns true when something was saved.
Future<bool> showScheduleClassDialog(
  BuildContext context, {
  required List<TeacherCourse> courses,
  String? courseId,
  ClassSession? existing,
  ClassRequest? request,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ScheduleDialog(
      courses: courses,
      courseId: courseId,
      existing: existing,
      request: request,
    ),
  );
  return saved ?? false;
}

class _ScheduleDialog extends ConsumerStatefulWidget {
  const _ScheduleDialog({
    required this.courses,
    this.courseId,
    this.existing,
    this.request,
  });

  final List<TeacherCourse> courses;
  final String? courseId;
  final ClassSession? existing;
  final ClassRequest? request;

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(
          text: widget.existing?.title ?? widget.request?.topic ?? '');
  late final TextEditingController _description =
      TextEditingController(
          text: widget.existing?.description ?? widget.request?.note ?? '');
  late String? _course = widget.existing?.courseId ??
      widget.request?.courseId ??
      widget.courseId ??
      (widget.courses.length == 1 ? widget.courses.first.course.id : null);
  late DateTime _date = widget.existing?.scheduledAt ??
      DateTime.now().add(const Duration(hours: 1));
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute);
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final course = _course;
    if (course == null) {
      showAppSnack(context, 'Choose the course for this class.', error: true);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(teacherRepositoryProvider);
    try {
      final existing = widget.existing;
      final request = widget.request;
      if (request != null) {
        await ref.read(classroomRepositoryProvider).scheduleFromRequest(
              requestId: request.id,
              title: _title.text.trim(),
              description: _description.text.trim(),
              when: _date,
            );
        ref.invalidate(teacherRequestsProvider);
      } else if (existing == null) {
        await repo.scheduleClass(
          courseId: course,
          title: _title.text.trim(),
          description: _description.text.trim(),
          when: _date,
        );
      } else {
        await repo.updateClass(
          id: existing.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          when: _date,
        );
      }
      ref.invalidate(teacherSessionsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showAppSnack(context, friendlyError(error), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final editing = widget.existing != null;
    final request = widget.request;
    return AlertDialog(
      backgroundColor: p.surface,
      title: Text(
        editing
            ? 'Edit class'
            : (request != null ? 'Schedule requested class' : 'Schedule a class'),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      '${request.studentLabel} asked for: ${request.topic}',
                      style: TextStyle(color: p.ink2, fontSize: 14, height: 1.4),
                    ),
                  ),
                if (widget.courses.length != 1 && !editing && request == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      value: _course,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Course'),
                      items: [
                        for (final c in widget.courses)
                          DropdownMenuItem(
                            value: c.course.id,
                            child: Text(
                              c.course.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _course = value),
                    ),
                  ),
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Class title',
                    hintText: 'For example: Week 2, Cell structure',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.length < 3) return 'Please write at least 3 letters';
                    if (text.length > 140) return 'Please keep it shorter';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What will you cover? (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(formatDate(_date)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(
                        '${_date.hour.toString().padLeft(2, '0')}:'
                        '${_date.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Enrolled students get an alert, and a reminder 15 minutes before.',
                  style: TextStyle(color: p.ink2, fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(editing ? 'Save' : 'Schedule'),
        ),
      ],
    );
  }
}
