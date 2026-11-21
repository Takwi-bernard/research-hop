import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/web_files.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../admin/data/admin_models.dart';
import '../../classroom/data/classroom_models.dart';
import '../../shell/page_frame.dart';
import '../application/student_providers.dart';
import '../data/student_models.dart';
import 'student_widgets.dart';

class StudentCoursePage extends ConsumerStatefulWidget {
  const StudentCoursePage({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<StudentCoursePage> createState() => _StudentCoursePageState();
}

class _StudentCoursePageState extends ConsumerState<StudentCoursePage> {
  bool _busy = false;

  Future<void> _cancel(MyRegistration reg) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this registration?',
      message: 'You have not paid yet. You can register again any time.',
      confirmLabel: 'Cancel registration',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(studentRepositoryProvider).cancelRegistration(reg.id);
      ref.invalidate(myRegistrationsProvider);
      if (mounted) showAppSnack(context, 'Registration cancelled');
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(CourseMaterial m) async {
    try {
      final url = await ref.read(studentRepositoryProvider).materialUrl(m);
      openInNewTab(url);
    } catch (error) {
      if (mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final catalog = ref.watch(catalogProvider);
    final regs = ref.watch(myRegistrationsProvider).value ?? const [];

    CatalogCourse? course;
    for (final c in catalog.value ?? const <CatalogCourse>[]) {
      if (c.id == widget.courseId) course = c;
    }
    final reg = registrationFor(regs, widget.courseId);

    return PageFrame(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/student/courses'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('All courses'),
            ),
          ),
          const SizedBox(height: 6),
          if (course == null)
            AsyncBody<List<CatalogCourse>>(
              value: catalog,
              onRetry: () => ref.invalidate(catalogProvider),
              builder: (_) => const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Course not found',
                message: 'It may have been removed or is not open yet.',
              ),
            )
          else
            _body(context, p, course, reg),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppPalette p,
    CatalogCourse course,
    MyRegistration? reg,
  ) {
    final meta = [
      if (course.category != null && course.category!.isNotEmpty)
        course.category!,
      if (course.levelLabel.isNotEmpty) course.levelLabel,
      if (course.durationLabel != null && course.durationLabel!.isNotEmpty)
        course.durationLabel!,
    ].join('  ·  ');
    final enrolled = reg?.status == RegStatus.approved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                course.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (reg != null) RegistrationChip(reg.status),
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meta, style: TextStyle(color: p.ink2, fontSize: 15)),
        ],
        const SizedBox(height: 16),
        if (course.description.isNotEmpty)
          Text(
            course.description,
            style: const TextStyle(fontSize: 16, height: 1.55),
          ),
        const SizedBox(height: 22),
        _actionCard(context, p, course, reg),
        if (enrolled) ...[
          const SizedBox(height: 24),
          _announcements(p),
          _classes(p),
          const SizedBox(height: 24),
          _content(p),
        ],
      ],
    );
  }

  Widget _actionCard(
    BuildContext context,
    AppPalette p,
    CatalogCourse course,
    MyRegistration? reg,
  ) {
    final fee = course.feeXaf == 0 ? 'Free' : formatXaf(course.feeXaf);
    final status = reg?.status;

    if (status == RegStatus.approved) {
      return SectionCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: p.accent),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You are enrolled in this course.',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (status == RegStatus.paid) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.warnBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Payment received. An administrator will confirm your place soon. '
          'You will get an alert as soon as it is done.',
          style: TextStyle(color: p.warnInk, height: 1.45, fontSize: 15.5),
        ),
      );
    }

    if (status == RegStatus.awaitingPayment && reg != null) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are registered. One step left: pay $fee.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton(
                  label: 'Pay $fee',
                  expand: false,
                  onPressed: () => context.go('/student/pay/${reg.id}'),
                ),
                AppButton(
                  label: 'Cancel registration',
                  style: AppButtonStyle.text,
                  expand: false,
                  onPressed: _busy ? null : () => _cancel(reg),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == RegStatus.rejected) ...[
            Row(
              children: [
                const StatusChip('Not approved', tone: ChipTone.bad),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reg?.rejectionReason ?? 'Please contact the administrator.',
                    style: TextStyle(color: p.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Text(
            course.feeXaf == 0
                ? 'This course is free.'
                : 'One-time fee: $fee',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Pay once with MTN or Orange Money. Your place is confirmed '
            'by an administrator.',
            style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: status == RegStatus.rejected
                ? 'Register again'
                : 'Register for this course',
            expand: false,
            onPressed: () =>
                context.go('/student/courses/${course.id}/register'),
          ),
        ],
      ),
    );
  }

  Widget _announcements(AppPalette p) {
    final items =
        ref.watch(studentAnnouncementsProvider(widget.courseId)).value ??
            const <Announcement>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Announcements', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final a in items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      timeAgo(a.createdAt),
                      style: TextStyle(color: p.ink2, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      a.body,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _classes(AppPalette p) {
    final all = ref.watch(courseClassesProvider(widget.courseId)).value ??
        const <ClassSession>[];
    final ahead = all.where((c) => c.live || c.scheduled).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = all.where((c) => c.status == ClassStatus.ended).take(5).toList();

    Widget tile(ClassSession c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: () => context.go('/student/classes/${c.id}'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatDateTime(c.scheduledAt),
                        style: TextStyle(color: p.ink2, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (c.live)
                  const StatusChip('Join now', tone: ChipTone.bad)
                else if (c.status == ClassStatus.ended)
                  const StatusChip('Read chat')
                else
                  Icon(Icons.chevron_right_rounded, color: p.ink2),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Classes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (ahead.isEmpty && past.isEmpty)
          Text(
            'No class is scheduled yet.',
            style: TextStyle(color: p.ink2, fontSize: 15),
          ),
        for (final c in ahead) tile(c),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Past classes', style: TextStyle(color: p.ink2, fontSize: 14)),
          const SizedBox(height: 8),
          for (final c in past) tile(c),
        ],
      ],
    );
  }

  Widget _content(AppPalette p) {
    final async = ref.watch(courseContentProvider(widget.courseId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes and files', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        AsyncBody<CourseContent>(
          value: async,
          onRetry: () => ref.invalidate(courseContentProvider(widget.courseId)),
          builder: (content) {
            if (content.notes.isEmpty && content.materials.isEmpty) {
              return Text(
                'Nothing here yet. Notes and files will appear as your '
                'teacher adds them.',
                style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
              );
            }
            final byNote = <String, List<CourseMaterial>>{};
            final loose = <CourseMaterial>[];
            for (final m in content.materials) {
              final id = m.moduleId;
              if (id != null && content.notes.any((n) => n.id == id)) {
                byNote.putIfAbsent(id, () => []).add(m);
              } else {
                loose.add(m);
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in content.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (note.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SelectableText(
                              note.description,
                              style: const TextStyle(fontSize: 15.5, height: 1.55),
                            ),
                          ],
                          for (final m in byNote[note.id] ?? const <CourseMaterial>[])
                            _fileTile(p, m),
                        ],
                      ),
                    ),
                  ),
                if (loose.isNotEmpty) ...[
                  Text('Files', style: TextStyle(color: p.ink2, fontSize: 14)),
                  for (final m in loose) _fileTile(p, m),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _fileTile(AppPalette p, CourseMaterial m) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.insert_drive_file_outlined, color: p.accent),
      title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatBytes(m.sizeBytes)),
      trailing: Icon(Icons.download_rounded, color: p.ink2),
      onTap: () => _open(m),
    );
  }
}
