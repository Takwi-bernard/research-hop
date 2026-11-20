import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../application/admin_providers.dart';
import '../data/admin_models.dart';

/// Records cash the administrator received. Search the student, pick the
/// course, confirm. The amount is always the course's fixed fee.
class CashPaymentDialog extends ConsumerStatefulWidget {
  const CashPaymentDialog({super.key, this.student, this.courseId});

  /// Pre-selected student (when opened from a registration).
  final StudentRef? student;
  final String? courseId;

  @override
  ConsumerState<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends ConsumerState<CashPaymentDialog> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  Timer? _debounce;

  List<StudentRef> _results = const [];
  bool _searching = false;
  String? _searchError;

  StudentRef? _student;
  List<StudentCourseState> _states = const [];
  bool _loadingStates = false;

  String? _courseId;
  bool _approve = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _courseId = widget.courseId;
    final s = widget.student;
    if (s != null) _pick(s);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final found =
            await ref.read(adminRepositoryProvider).searchStudents(value);
        if (!mounted || _search.text != value) return;
        setState(() {
          _results = found;
          _searching = false;
          _searchError = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _searching = false;
          _searchError = friendlyError(error);
        });
      }
    });
  }

  Future<void> _pick(StudentRef student) async {
    setState(() {
      _student = student;
      _loadingStates = true;
      _states = const [];
      _error = null;
    });
    try {
      final states =
          await ref.read(adminRepositoryProvider).studentCourseStates(student.id);
      if (!mounted) return;
      setState(() {
        _states = states;
        _loadingStates = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingStates = false;
        _error = friendlyError(error);
      });
    }
  }

  RegStatus? _stateOf(String courseId) {
    for (final s in _states) {
      if (s.courseId == courseId) return s.status;
    }
    return null;
  }

  Future<void> _confirm(CourseSummary course) async {
    final student = _student;
    if (student == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).recordCashPayment(
            studentId: student.id,
            courseId: course.id,
            note: _note.text.trim(),
            approve: _approve,
          );
      ref.invalidate(adminPaymentsProvider);
      ref.invalidate(adminRegistrationsProvider);
      ref.invalidate(adminOverviewProvider);
      ref.invalidate(adminCoursesProvider);
      if (mounted) Navigator.of(context).pop(student.displayName);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final courses = (ref.watch(adminCoursesProvider).value ?? const [])
        .where((c) => c.status == CourseStatus.published && c.feeXaf > 0)
        .toList();
    CourseSummary? selected;
    for (final c in courses) {
      if (c.id == _courseId) selected = c;
    }

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: p.surface,
        title: const Text('Record cash payment'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepLabel('1. Student'),
                if (_student == null) ..._searchStep(p) else _studentCard(p),
                if (_student != null) ...[
                  const SizedBox(height: 20),
                  _stepLabel('2. Course'),
                  if (_loadingStates)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (courses.isEmpty)
                    Text(
                      'There are no published courses with a fee.',
                      style: TextStyle(color: p.ink2),
                    )
                  else
                    for (final c in courses) _courseTile(p, c),
                ],
                if (selected != null) ...[
                  const SizedBox(height: 20),
                  _stepLabel('3. Confirm'),
                  _confirmBox(p, selected),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: p.danger, height: 1.4)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: (_busy || selected == null) ? null : () => _confirm(selected!),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(
                    selected == null
                        ? 'Record payment'
                        : 'Record ${formatXaf(_feeFor(selected))}',
                  ),
          ),
        ],
      ),
    );
  }

  int _feeFor(CourseSummary c) => c.feeXaf;

  Widget _stepLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: context.palette.ink2,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  List<Widget> _searchStep(AppPalette p) {
    return [
      TextField(
        controller: _search,
        autofocus: true,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Search by name or phone number',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 8),
      if (_searching)
        const Padding(
          padding: EdgeInsets.all(10),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        )
      else if (_searchError != null)
        Text(_searchError!, style: TextStyle(color: p.danger))
      else if (_search.text.trim().length < 2)
        Text(
          'Type at least 2 letters. The student must have an account.',
          style: TextStyle(color: p.ink2, fontSize: 14),
        )
      else if (_results.isEmpty)
        Text('No student found.', style: TextStyle(color: p.ink2))
      else
        for (final s in _results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: p.softBg,
              foregroundColor: p.softInk,
              child: Text(s.displayName.substring(0, 1).toUpperCase()),
            ),
            title: Text(s.displayName),
            subtitle: Text(
              [
                if (s.phone != null && s.phone!.isNotEmpty) s.phone!,
                if (s.city != null && s.city!.isNotEmpty) s.city!,
              ].join('  ·  '),
            ),
            onTap: () => _pick(s),
          ),
    ];
  }

  Widget _studentCard(AppPalette p) {
    final s = _student!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: p.softBg,
            foregroundColor: p.softInk,
            child: Text(s.displayName.substring(0, 1).toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (s.phone != null && s.phone!.isNotEmpty)
                  Text(s.phone!, style: TextStyle(color: p.ink2, fontSize: 13.5)),
              ],
            ),
          ),
          if (widget.student == null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _student = null;
                        _courseId = null;
                        _states = const [];
                      }),
              child: const Text('Change'),
            ),
        ],
      ),
    );
  }

  Widget _courseTile(AppPalette p, CourseSummary c) {
    final state = _stateOf(c.id);
    String? blocked;
    if (state == RegStatus.approved) blocked = 'Already enrolled';
    if (state == RegStatus.paid) {
      blocked = 'Paid, waiting for approval (see Registrations)';
    }
    final note = blocked ??
        (state == RegStatus.awaitingPayment ? 'Registered, not paid yet' : null);

    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      value: c.id,
      groupValue: _courseId,
      onChanged: (blocked != null || _busy)
          ? null
          : (value) => setState(() => _courseId = value),
      title: Text(c.title),
      subtitle: Text(
        note == null ? formatXaf(c.feeXaf) : '${formatXaf(c.feeXaf)}  ·  $note',
      ),
    );
  }

  Widget _confirmBox(AppPalette p, CourseSummary c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.softBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Cash received: ${formatXaf(c.feeXaf)}\n'
            'This is the fixed fee for ${c.title}.',
            style: TextStyle(color: p.softInk, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'For example: paid at the office, receipt 014',
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _approve,
          onChanged: _busy ? null : (v) => setState(() => _approve = v),
          title: const Text('Give access right away'),
          subtitle: const Text(
            'Turn off to keep it under "To approve" instead.',
          ),
        ),
      ],
    );
  }
}
