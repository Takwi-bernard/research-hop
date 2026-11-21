import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../shell/page_frame.dart';
import '../application/student_providers.dart';
import '../data/student_models.dart';
import 'student_widgets.dart';

class StudentCoursesPage extends ConsumerStatefulWidget {
  const StudentCoursesPage({super.key});

  @override
  ConsumerState<StudentCoursesPage> createState() => _StudentCoursesPageState();
}

class _StudentCoursesPageState extends ConsumerState<StudentCoursesPage> {
  String _query = '';
  int _category = 0;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final regs = ref.watch(myRegistrationsProvider).value ?? const [];

    return PageFrame(
      maxWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Courses',
            subtitle: 'Pick a course, register and pay once.',
          ),
          AsyncBody<List<CatalogCourse>>(
            value: catalog,
            onRetry: () => ref.invalidate(catalogProvider),
            builder: (all) {
              final categories = <String>{
                for (final c in all)
                  if (c.category != null && c.category!.trim().isNotEmpty)
                    c.category!.trim(),
              }.toList()
                ..sort();
              final index = _category > categories.length ? 0 : _category;
              final q = _query.trim().toLowerCase();
              final shown = all.where((c) {
                if (index > 0 && c.category?.trim() != categories[index - 1]) {
                  return false;
                }
                if (q.isEmpty) return true;
                return c.title.toLowerCase().contains(q) ||
                    c.description.toLowerCase().contains(q) ||
                    (c.category ?? '').toLowerCase().contains(q);
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search courses',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i <= categories.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _CategoryChip(
                                label: i == 0 ? 'All' : categories[i - 1],
                                selected: i == index,
                                onTap: () => setState(() => _category = i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: all.isEmpty ? 'No courses yet' : 'No matches',
                      message: all.isEmpty
                          ? 'New courses are added regularly. Check back soon.'
                          : 'Try a different word or category.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 14.0;
                        final columns = constraints.maxWidth >= 720 ? 2 : 1;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final c in shown)
                              SizedBox(
                                width: width,
                                child: _CourseCard(
                                  course: c,
                                  registration: registrationFor(regs, c.id),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? p.softInk : p.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: p.surface,
      selectedColor: p.softBg,
      side: BorderSide(color: selected ? p.accent : p.line),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.registration});

  final CatalogCourse course;
  final MyRegistration? registration;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = course;
    final meta = [
      if (c.category != null && c.category!.isNotEmpty) c.category!,
      if (c.levelLabel.isNotEmpty) c.levelLabel,
      if (c.durationLabel != null && c.durationLabel!.isNotEmpty)
        c.durationLabel!,
    ].join('  ·  ');

    return SectionCard(
      onTap: () => context.go('/student/courses/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (registration != null) ...[
                const SizedBox(width: 8),
                RegistrationChip(registration!.status),
              ],
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(color: p.ink2, fontSize: 14)),
          ],
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              c.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink2, fontSize: 15, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            c.feeXaf == 0 ? 'Free' : formatXaf(c.feeXaf),
            style: TextStyle(
              color: p.accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
