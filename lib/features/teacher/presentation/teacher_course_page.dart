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
import '../../admin/data/admin_models.dart';
import '../../classroom/application/classroom_providers.dart';
import '../../classroom/data/classroom_models.dart';
import '../../shell/page_frame.dart';
import '../../student/application/student_providers.dart';
import '../../student/data/student_models.dart';
import '../application/teacher_providers.dart';
import '../data/teacher_repository.dart';
import 'schedule_class_dialog.dart';
import 'teacher_widgets.dart';

class TeacherCoursePage extends ConsumerWidget {
  const TeacherCoursePage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final courses = ref.watch(teacherCoursesProvider);

    return PageFrame(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/teacher/courses'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('My courses'),
            ),
          ),
          AsyncBody<List<TeacherCourse>>(
            value: courses,
            onRetry: () => ref.invalidate(teacherCoursesProvider),
            builder: (all) {
              TeacherCourse? item;
              for (final c in all) {
                if (c.course.id == courseId) item = c;
              }
              if (item == null) {
                return const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Course not found',
                  message: 'It may not be assigned to you.',
                );
              }
              return _Body(item: item, all: all, p: p);
            },
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item, required this.all, required this.p});

  final TeacherCourse item;
  final List<TeacherCourse> all;
  final AppPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = item.course;
    final meta = [
      if (c.category != null && c.category!.isNotEmpty) c.category!,
      if (c.levelLabel.isNotEmpty) c.levelLabel,
      if (c.durationLabel != null && c.durationLabel!.isNotEmpty)
        c.durationLabel!,
      '${item.students} ${item.students == 1 ? 'student' : 'students'}',
    ].join('  ·  ');

    final sessions = (ref.watch(teacherSessionsProvider).value ?? const [])
        .where((s) => s.courseId == c.id)
        .toList();
    final ahead = sessions.where((s) => s.live || s.scheduled).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = sessions.where((s) => s.finished).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(c.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(meta, style: TextStyle(color: p.ink2, fontSize: 15)),
        if (c.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(c.description, style: const TextStyle(fontSize: 16, height: 1.55)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Classes', style: Theme.of(context).textTheme.titleLarge),
            ),
            AppButton(
              label: 'Schedule',
              expand: false,
              leading: const Icon(Icons.add_rounded, size: 18),
              onPressed: () => showScheduleClassDialog(
                context,
                courses: all,
                courseId: c.id,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ahead.isEmpty && past.isEmpty)
          Text('No class yet for this course.', style: TextStyle(color: p.ink2))
        else ...[
          for (final s in ahead)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherSessionTile(
                session: s,
                courses: all,
                showCourse: false,
              ),
            ),
          for (final s in past.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TeacherSessionTile(
                session: s,
                courses: all,
                showCourse: false,
              ),
            ),
        ],
        const SizedBox(height: 26),
        _Announcements(courseId: c.id),
        const SizedBox(height: 26),
        _Content(courseId: c.id),
      ],
    );
  }
}

class _Announcements extends ConsumerWidget {
  const _Announcements({required this.courseId});

  final String courseId;

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    final values = await showFieldsDialog(
      context,
      title: 'Announcement',
      message: 'Every enrolled student gets an alert.',
      confirmLabel: 'Post',
      fields: const [
        DialogField(label: 'Title', required: true),
        DialogField(label: 'Message', maxLines: 5, required: true),
      ],
    );
    if (values == null) return;
    if (values[0].length < 3) {
      if (context.mounted) {
        showAppSnack(context, 'The title needs at least 3 letters.', error: true);
      }
      return;
    }
    try {
      await ref
          .read(classroomRepositoryProvider)
          .postAnnouncement(courseId, values[0], values[1]);
      ref.invalidate(courseAnnouncementsProvider(courseId));
      if (context.mounted) showAppSnack(context, 'Announcement sent');
    } catch (error) {
      if (context.mounted) showAppSnack(context, friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final async = ref.watch(courseAnnouncementsProvider(courseId));
    final myId = ref.watch(teacherRepositoryProvider).myId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Announcements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            AppButton(
              label: 'New',
              expand: false,
              style: AppButtonStyle.outlined,
              leading: const Icon(Icons.campaign_outlined, size: 18),
              onPressed: () => _post(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncBody<List<Announcement>>(
          value: async,
          onRetry: () => ref.invalidate(courseAnnouncementsProvider(courseId)),
          builder: (items) {
            if (items.isEmpty) {
              return Text(
                'Nothing posted yet.',
                style: TextStyle(color: p.ink2, fontSize: 15),
              );
            }
            return Column(
              children: [
                for (final a in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (a.authorId == myId)
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: p.ink2),
                                  onPressed: () async {
                                    final ok = await confirmDialog(
                                      context,
                                      title: 'Delete this announcement?',
                                      message: 'Students will no longer see it.',
                                      confirmLabel: 'Delete',
                                      danger: true,
                                    );
                                    if (!ok) return;
                                    try {
                                      await ref
                                          .read(classroomRepositoryProvider)
                                          .deleteAnnouncement(a.id);
                                      ref.invalidate(
                                        courseAnnouncementsProvider(courseId),
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        showAppSnack(
                                          context,
                                          friendlyError(error),
                                          error: true,
                                        );
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                          Text(
                            timeAgo(a.createdAt),
                            style: TextStyle(color: p.ink2, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            a.body,
                            style: const TextStyle(fontSize: 15.5, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Notes and files an administrator added to the course (read only).
class _Content extends ConsumerWidget {
  const _Content({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final async = ref.watch(courseContentProvider(courseId));

    Future<void> open(CourseMaterial m) async {
      try {
        final url = await ref.read(studentRepositoryProvider).materialUrl(m);
        openInNewTab(url);
      } catch (error) {
        if (context.mounted) showAppSnack(context, friendlyError(error), error: true);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes and files', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Added by the administrator. Students see the same material.',
          style: TextStyle(color: p.ink2, fontSize: 14),
        ),
        const SizedBox(height: 12),
        AsyncBody<CourseContent>(
          value: async,
          onRetry: () => ref.invalidate(courseContentProvider(courseId)),
          builder: (content) {
            if (content.notes.isEmpty && content.materials.isEmpty) {
              return Text(
                'No notes or files yet.',
                style: TextStyle(color: p.ink2, fontSize: 15),
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
            Widget tile(CourseMaterial m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.insert_drive_file_outlined, color: p.accent),
                  title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatBytes(m.sizeBytes)),
                  trailing: Icon(Icons.download_rounded, color: p.ink2),
                  onTap: () => open(m),
                );
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
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (note.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SelectableText(
                              note.description,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ],
                          for (final m in byNote[note.id] ?? const <CourseMaterial>[])
                            tile(m),
                        ],
                      ),
                    ),
                  ),
                for (final m in loose) tile(m),
              ],
            );
          },
        ),
      ],
    );
  }
}
