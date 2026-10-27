/// The academic curriculum hub («قسم المواد الدراسية»).
///
/// The student picks a grade, then a branch or track, and sees every subject
/// with its real progress from the bundled library. Each card opens
/// [SubjectScreen].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/curriculum.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The subjects overview screen.
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key, this.gradeId, this.trackId});

  final String? gradeId;
  final String? trackId;

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  late String _gradeId;
  String? _trackId;

  @override
  void initState() {
    super.initState();
    final selected = ref.read(selectedGradeProvider);
    _gradeId = widget.gradeId != null &&
            curriculumGrades.containsKey(widget.gradeId)
        ? widget.gradeId!
        : (curriculumGrades.containsKey(selected) ? selected : 'sec1');
    _trackId =
        curriculumTrack(_gradeId, widget.trackId)?.id ??
        curriculumForGrade(_gradeId)?.defaultTrack?.id;
  }

  void _selectGrade(String gradeId) {
    if (gradeId == _gradeId) return;
    setState(() {
      _gradeId = gradeId;
      _trackId = curriculumForGrade(gradeId)?.defaultTrack?.id;
    });
    ref.read(selectedGradeProvider.notifier).state = gradeId;
  }

  @override
  Widget build(BuildContext context) {
    final gradesAsync = ref.watch(gradesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const TrText('المواد الدراسية'),
        actions: [
          IconButton(
            tooltip: 'مكتبة الكتب',
            onPressed: () => context.push(ZakerRoutes.courses),
            icon: const Icon(Icons.local_library_outlined),
          ),
        ],
      ),
      body: gradesAsync.when(
        loading: () => const LoadingBox(label: 'بنجهز المنهج…'),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مش قادرين نحمّل المنهج',
          message: '$error',
        ),
        data: (grades) {
          Grade? grade;
          for (final item in grades) {
            if (item.id == _gradeId) {
              grade = item;
              break;
            }
          }
          if (grade == null) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'المنهج مش متاح',
              message: 'جرّب تختار صف تاني.',
            );
          }
          return _CurriculumBody(
            grade: grade,
            gradeId: _gradeId,
            trackId: _trackId,
            onGrade: _selectGrade,
            onTrack: (trackId) => setState(() => _trackId = trackId),
          );
        },
      ),
    );
  }
}

class _CurriculumBody extends ConsumerWidget {
  const _CurriculumBody({
    required this.grade,
    required this.gradeId,
    required this.trackId,
    required this.onGrade,
    required this.onTrack,
  });

  final Grade grade;
  final String gradeId;
  final String? trackId;
  final ValueChanged<String> onGrade;
  final ValueChanged<String?> onTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculum = curriculumForGrade(gradeId);
    if (curriculum == null) return const SizedBox.shrink();
    final subjects = curriculumSubjects(gradeId: gradeId, trackId: trackId);
    final read = ref.watch(readLessonsProvider);
    final track = curriculumTrack(gradeId, trackId);
    final totalLessons = subjects.fold<int>(
      0,
      (sum, subject) =>
          sum +
          subjectLessonCount(subject: subject, grade: grade, track: track),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.sm,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        _CurriculumHeader(
          curriculum: curriculum,
          subjects: subjects.length,
          lessons: totalLessons,
        ),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(
          title: 'الصف الدراسي',
          icon: Icons.school_rounded,
        ),
        const SizedBox(height: ZakerSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in curriculumGrades.values) ...[
                ChoiceChip(
                  label: TrText(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: item.id == gradeId,
                  onSelected: (_) => onGrade(item.id),
                ),
                const SizedBox(width: ZakerSpacing.sm),
              ],
            ],
          ),
        ),
        if (curriculum.tracks.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: curriculum.id == 'sec3' ? 'اختر المسار' : 'اختر الشعبة',
            icon: Icons.alt_route_rounded,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              for (final item in curriculum.tracks)
                ChoiceChip(
                  avatar: item.id == trackId
                      ? const Icon(Icons.check_rounded, size: 16)
                      : const Icon(Icons.school_outlined, size: 16),
                  label: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: item.id == trackId,
                  onSelected: (_) => onTrack(item.id),
                ),
            ],
          ),
          if (track != null) ...[
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              track.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        const SizedBox(height: ZakerSpacing.xl),
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'المواد الدراسية',
                icon: Icons.auto_stories_rounded,
              ),
            ),
            StatChip(
              value: '${subjects.length}',
              label: 'مادة',
              icon: Icons.menu_book_outlined,
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 3 : 2;
            const spacing = ZakerSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final subject in subjects)
                  SizedBox(
                    width: width,
                    child: _SubjectCard(
                      subject: subject,
                      grade: grade,
                      track: track,
                      read: read,
                      onTap: () => context.push(
                        ZakerRoutes.subjectPath(
                          gradeId,
                          subject.id,
                          track: trackId,
                        ),
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

/// The teal hero card at the top of the hub.
class _CurriculumHeader extends StatelessWidget {
  const _CurriculumHeader({
    required this.curriculum,
    required this.subjects,
    required this.lessons,
  });

  final CurriculumGrade curriculum;
  final int subjects;
  final int lessons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ZakerColors.navy, ZakerColors.navyLight, ZakerColors.navyDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: ZakerColors.primary.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 14,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZakerSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ZakerSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(ZakerRadius.md),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: ZakerSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            'منهج الثانوي',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TrText(
                            curriculum.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.md),
                TrText(
                  curriculum.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.md),
                Row(
                  children: [
                    _GlassStat(
                      value: '$subjects',
                      label: 'مادة',
                      icon: Icons.auto_stories_outlined,
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    _GlassStat(
                      value: '$lessons',
                      label: 'درس',
                      icon: Icons.play_lesson_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent stat pill for use on top of the teal hero gradient.
class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          TrText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          TrText(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single subject card with its real read progress.
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.grade,
    required this.track,
    required this.read,
    required this.onTap,
  });

  final CurriculumSubject subject;
  final Grade grade;
  final CurriculumTrack? track;
  final Set<String> read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = cardAccentOf(subject.color, theme);
    final books = curriculumBooks(
      grade: grade,
      subject: subject,
      track: track,
    );
    final lessons = subjectLessonCount(
      subject: subject,
      grade: grade,
      track: track,
    );
    final progress = subjectProgress(
      curriculum: curriculumForGrade(grade.id)!,
      subject: subject,
      grade: grade,
      readLessons: read,
      track: track,
    );
    final percent = (progress * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZakerRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                subject.color.withValues(alpha: isDark ? 0.26 : 0.12),
                theme.cardTheme.color ?? Colors.white,
              ],
            ),
            border: Border.all(
              color: subject.color.withValues(alpha: isDark ? 0.32 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: subject.color.withValues(alpha: isDark ? 0.14 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            subject.color,
                            subject.color.withValues(alpha: 0.72),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: subject.color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        subject.icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (books.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZakerColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const TrText(
                          'قريبًا',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ZakerColors.accent,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  subject.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  subject.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ProgressBar(
                        value: progress,
                        height: 5,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$percent%',
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TrText(
                  books.isEmpty
                      ? 'المحتوى هيتضاف قريب'
                      : '${books.length} كتاب · $lessons درس',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
