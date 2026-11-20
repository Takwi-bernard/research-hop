import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/web_files.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../shell/page_frame.dart';
import '../application/admin_providers.dart';
import 'note_composer_dialog.dart';
import '../data/admin_models.dart';

const _levels = <String?, String>{
  null: 'Any level',
  'beginner': 'Beginner',
  'intermediate': 'Intermediate',
  'advanced': 'Advanced',
};

/// Create a course (courseId == null) or manage an existing one.
class CourseEditorPage extends ConsumerStatefulWidget {
  const CourseEditorPage({super.key, this.courseId});

  final String? courseId;

  @override
  ConsumerState<CourseEditorPage> createState() => _CourseEditorPageState();
}

class _CourseEditorPageState extends ConsumerState<CourseEditorPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _duration = TextEditingController();
  final _fee = TextEditingController(text: '0');
  String? _level;
  CourseStatus _status = CourseStatus.draft;
  bool _filled = false;
  bool _saving = false;
  bool _working = false;

  bool get _isNew => widget.courseId == null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _duration.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _fillFrom(CourseSummary c) {
    _title.text = c.title;
    _description.text = c.description;
    _category.text = c.category ?? '';
    _duration.text = c.durationLabel ?? '';
    _fee.text = '${c.feeXaf}';
    _level = c.level;
    _status = c.status;
    _filled = true;
  }

  void _refresh() {
    final id = widget.courseId;
    if (id != null) ref.invalidate(adminCourseProvider(id));
    ref.invalidate(adminCoursesProvider);
    ref.invalidate(adminOverviewProvider);
  }

  Future<void> _guard(Future<void> Function() job, {String? done}) async {
    setState(() => _working = true);
    try {
      await job();
      _refresh();
      if (done != null && mounted) showAppSnack(context, done);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save(CourseDetail? detail) async {
    if (!(_form.currentState?.validate() ?? false)) return;

    if (_status == CourseStatus.published &&
        detail != null &&
        detail.summary.teachers.isEmpty) {
      final ok = await confirmDialog(
        context,
        title: 'Publish without a teacher?',
        message: 'No teacher is assigned yet. Students will be able to '
            'register, but nobody can run the classes.',
        confirmLabel: 'Publish anyway',
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(adminRepositoryProvider).saveCourse(
            id: widget.courseId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category.text.trim(),
            level: _level,
            durationLabel: _duration.text.trim(),
            feeXaf: int.parse(_fee.text.trim()),
            status: _status,
          );
      _refresh();
      if (!mounted) return;
      if (_isNew) {
        showAppSnack(context, 'Course created. Now add a teacher and notes.');
        context.go('/admin/courses/$id');
      } else {
        showAppSnack(context, 'Changes saved');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this course?',
      message: 'Its notes and files are deleted too. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _working = true);
    try {
      await ref.read(adminRepositoryProvider).deleteCourse(widget.courseId!);
      ref.invalidate(adminCoursesProvider);
      ref.invalidate(adminOverviewProvider);
      if (mounted) {
        showAppSnack(context, 'Course deleted');
        context.go('/admin/courses');
      }
    } on PostgrestException catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        error.code == '23503'
            ? 'Students have registered for this course, so it cannot be '
                'deleted. Archive it instead.'
            : friendlyError(error),
        error: true,
      );
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ----- teachers -----

  Future<void> _addTeachers(CourseDetail detail) async {
    final repo = ref.read(adminRepositoryProvider);
    List<TeacherRef> all;
    try {
      all = await repo.approvedTeachers();
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
      return;
    }
    final assigned = detail.summary.teachers.map((t) => t.id).toSet();
    final available = all.where((t) => !assigned.contains(t.id)).toList();
    if (!mounted) return;
    if (available.isEmpty) {
      showAppSnack(
        context,
        all.isEmpty
            ? 'No approved teachers yet. Approve one under Teachers first.'
            : 'Every approved teacher is already on this course.',
      );
      return;
    }
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _TeacherPickerDialog(teachers: available),
    );
    if (picked == null || picked.isEmpty) return;
    await _guard(() async {
      for (final id in picked) {
        await repo.assignTeacher(detail.summary.id, id);
      }
    }, done: picked.length == 1 ? 'Teacher added' : 'Teachers added');
  }

  Future<void> _removeTeacher(CourseDetail detail, TeacherRef t) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${t.name.isEmpty ? 'this teacher' : t.name}?',
      message: 'They will no longer see this course or its classes.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await _guard(
      () => ref
          .read(adminRepositoryProvider)
          .unassignTeacher(detail.summary.id, t.id),
      done: 'Teacher removed',
    );
  }

  // ----- notes and files -----

  Future<void> _openComposer(CourseDetail detail, {CourseNote? note}) async {
    final next = detail.notes.isEmpty
        ? 1
        : detail.notes.map((n) => n.position).reduce((a, b) => a > b ? a : b) + 1;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NoteComposerDialog(
        courseId: detail.summary.id,
        nextPosition: next,
        note: note,
      ),
    );
    if (saved == true) {
      _refresh();
      if (mounted) showAppSnack(context, 'Saved');
    }
  }

  Future<void> _deleteNote(CourseNote note, int fileCount) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${note.title}"?',
      message: fileCount == 0
          ? 'Students will no longer see this note.'
          : 'Students will no longer see this note or its '
              '${fileCount == 1 ? 'file' : '$fileCount files'}.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    final repo = ref.read(adminRepositoryProvider);
    final detail = ref.read(adminCourseProvider(widget.courseId!)).value;
    await _guard(() async {
      // Remove the stored files first, then the note (rows go with it).
      final files = detail?.materials.where((m) => m.moduleId == note.id) ?? [];
      for (final m in files) {
        await repo.deleteMaterial(m);
      }
      await repo.deleteNote(note.id);
    }, done: 'Note deleted');
  }

  Future<void> _open(CourseMaterial m) async {
    try {
      final url = await ref.read(adminRepositoryProvider).materialUrl(m);
      openInNewTab(url);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  Future<void> _deleteMaterial(CourseMaterial m) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${m.title}"?',
      message: 'Students will no longer be able to download it.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await _guard(
      () => ref.read(adminRepositoryProvider).deleteMaterial(m),
      done: 'File deleted',
    );
  }

  // ----- build -----

  @override
  Widget build(BuildContext context) {
    final id = widget.courseId;
    final async = id == null ? null : ref.watch(adminCourseProvider(id));
    final detail = async?.value;

    if (detail != null && !_filled) _fillFrom(detail.summary);

    final Widget body;
    if (_isNew) {
      body = _detailsCard(null);
    } else if (detail == null) {
      body = AsyncBody<CourseDetail>(
        value: async!,
        onRetry: () => ref.invalidate(adminCourseProvider(id!)),
        builder: (_) => const SizedBox.shrink(),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailsCard(detail),
          const SizedBox(height: 16),
          _teachersCard(detail),
          const SizedBox(height: 16),
          _contentCard(detail),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Delete course',
              style: AppButtonStyle.text,
              expand: false,
              onPressed: _working ? null : _delete,
            ),
          ),
        ],
      );
    }

    return PageFrame(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/admin/courses'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('All courses'),
            ),
          ),
          const SizedBox(height: 6),
          PageHeader(
            title: _isNew ? 'New course' : (detail?.summary.title ?? 'Course'),
            subtitle: _isNew
                ? 'Start with the basics. You can add teachers, notes and '
                    'files right after saving.'
                : null,
          ),
          body,
        ],
      ),
    );
  }

  Widget _heading(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _detailsCard(CourseDetail? detail) {
    final p = context.palette;
    return SectionCard(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('Details'),
            AppTextField(
              label: 'Title',
              controller: _title,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 3) return 'Enter at least 3 characters';
                if (t.length > 120) return 'Keep it under 120 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Description',
              hint: 'What the course is about and who it is for',
              controller: _description,
              maxLines: 5,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Category',
                    hint: 'e.g. Mathematics',
                    controller: _category,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'Duration',
                    hint: 'e.g. 8 weeks',
                    controller: _duration,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FeeField(controller: _fee),
            const SizedBox(height: 16),
            Text('Level', style: TextStyle(color: p.ink2, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _levels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _level == entry.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _level = entry.key),
                    selectedColor: p.softBg,
                    backgroundColor: p.surface,
                    side: BorderSide(
                      color: _level == entry.key ? p.accent : p.line,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Status', style: TextStyle(color: p.ink2, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in CourseStatus.values)
                  ChoiceChip(
                    label: Text(courseStatusLabel(s)),
                    selected: _status == s,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: p.softBg,
                    backgroundColor: p.surface,
                    side: BorderSide(color: _status == s ? p.accent : p.line),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Only published courses are visible to students.',
              style: TextStyle(color: p.ink2, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: _isNew ? 'Create course' : 'Save changes',
              loading: _saving,
              onPressed: _saving ? null : () => _save(detail),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teachersCard(CourseDetail detail) {
    final p = context.palette;
    final teachers = detail.summary.teachers;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Teachers',
            trailing: AppButton(
              label: 'Add',
              style: AppButtonStyle.outlined,
              expand: false,
              onPressed: _working ? null : () => _addTeachers(detail),
            ),
          ),
          if (teachers.isEmpty)
            Text(
              'No teacher yet. Add one so classes can be scheduled.',
              style: TextStyle(color: p.warnInk, fontSize: 15),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in teachers)
                  InputChip(
                    label: Text(t.name.isEmpty ? 'Teacher' : t.name),
                    backgroundColor: p.softBg,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: p.softInk,
                      fontWeight: FontWeight.w600,
                    ),
                    deleteIconColor: p.softInk,
                    onDeleted: _working ? null : () => _removeTeacher(detail, t),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _contentCard(CourseDetail detail) {
    final p = context.palette;
    final byNote = <String, List<CourseMaterial>>{};
    final loose = <CourseMaterial>[];
    for (final m in detail.materials) {
      final id = m.moduleId;
      if (id == null || !detail.notes.any((n) => n.id == id)) {
        loose.add(m);
      } else {
        byNote.putIfAbsent(id, () => []).add(m);
      }
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Notes and files',
            trailing: AppButton(
              label: 'Add',
              style: AppButtonStyle.outlined,
              expand: false,
              leading: Icon(Icons.add_rounded, size: 20, color: p.ink),
              onPressed: _working ? null : () => _openComposer(detail),
            ),
          ),
          if (detail.notes.isEmpty && loose.isEmpty)
            Text(
              'Write a note, attach a file to it, and upload both together. '
              'Only registered students and the course teachers can see them.',
              style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
            ),
          for (final note in detail.notes)
            _noteTile(detail, note, byNote[note.id] ?? const []),
          if (loose.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Other files', style: TextStyle(color: p.ink2, fontSize: 14)),
            for (final m in loose) _fileTile(m),
          ],
        ],
      ),
    );
  }

  Widget _noteTile(
    CourseDetail detail,
    CourseNote note,
    List<CourseMaterial> files,
  ) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit or attach a file',
                onPressed:
                    _working ? null : () => _openComposer(detail, note: note),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed:
                    _working ? null : () => _deleteNote(note, files.length),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          if (note.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: Text(
                note.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.ink2, height: 1.4),
              ),
            ),
          for (final m in files) _fileTile(m, dense: true),
        ],
      ),
    );
  }

  Widget _fileTile(CourseMaterial m, {bool dense = false}) {
    final p = context.palette;
    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.insert_drive_file_outlined, color: p.accent),
      title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatBytes(m.sizeBytes)),
      onTap: () => _open(m),
      trailing: IconButton(
        tooltip: 'Delete file',
        onPressed: _working ? null : () => _deleteMaterial(m),
        icon: const Icon(Icons.close_rounded, size: 20),
      ),
    );
  }
}

class _FeeField extends StatelessWidget {
  const _FeeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Fee (FCFA)',
      helper: 'Paid once at registration. Use 0 for a free course.',
      controller: controller,
      keyboardType: TextInputType.number,
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return 'Enter the fee, or 0 for free';
        final value = int.tryParse(text);
        if (value == null) return 'Numbers only';
        if (value > 100000000) return 'That fee looks too high';
        return null;
      },
    );
  }
}

class _TeacherPickerDialog extends StatefulWidget {
  const _TeacherPickerDialog({required this.teachers});

  final List<TeacherRef> teachers;

  @override
  State<_TeacherPickerDialog> createState() => _TeacherPickerDialogState();
}

class _TeacherPickerDialogState extends State<_TeacherPickerDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      backgroundColor: p.surface,
      title: const Text('Add teachers'),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in widget.teachers)
              CheckboxListTile(
                value: _selected.contains(t.id),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(t.name.isEmpty ? 'Unnamed teacher' : t.name),
                onChanged: (on) => setState(() {
                  if (on ?? false) {
                    _selected.add(t.id);
                  } else {
                    _selected.remove(t.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
