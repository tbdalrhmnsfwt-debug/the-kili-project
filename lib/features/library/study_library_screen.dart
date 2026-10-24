/// The «المكتبة الدراسية» hub: every grade, grouped by stage.
///
/// This is the body of the second bottom-navigation tab and the `/courses`
/// destination. Each grade card opens [StudyGradeScreen], which lists the
/// subjects derived from that grade's own bundled books.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/study_library.dart';
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../home/shell_screen.dart';
import 'library_widgets.dart';

/// The Study Library root screen.
class StudyLibraryScreen extends ConsumerWidget {
  const StudyLibraryScreen({super.key});

  /// Searches every grade's books; picking one opens its lesson list.
  Future<void> _search(BuildContext context, List<Grade>? grades) async {
    if (grades == null || grades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('لسه بنحمّل الكتب — جرّب تاني بعد لحظة.'),
        ),
      );
      return;
    }
    final book = await showSearch<Book?>(
      context: context,
      delegate: BookSearchDelegate(grades),
    );
    if (book == null || !context.mounted) return;
    await context.push(ZakerRoutes.lessonPath(book));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesProvider);
    final read = ref.watch(readLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuLeading(context),
        title: const TrText('المكتبة الدراسية'),
        actions: [
          IconButton(
            tooltip: 'ابحث في كل الكتب',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _search(context, gradesAsync.valueOrNull),
          ),
        ],
      ),
      body: gradesAsync.when(
        loading: () => const LoadingBox(label: 'بنجهز المكتبة…'),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'مش قادرين نحمّل المكتبة',
          message: '$error',
        ),
        data: (grades) => _LibraryBody(grades: grades, read: read),
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({required this.grades, required this.read});

  final List<Grade> grades;
  final Set<String> read;

  @override
  Widget build(BuildContext context) {
    final totalBooks = grades.fold<int>(
      0,
      (sum, grade) => sum + grade.books.length,
    );
    final totalLessons = grades.fold<int>(
      0,
      (sum, grade) => sum + studyLessonCount(grade),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.sm,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        _LibraryHero(
          grades: grades.length,
          books: totalBooks,
          lessons: totalLessons,
        ),
        const SizedBox(height: ZakerSpacing.xl),
        for (final stage in StudyStage.values) ..._stageSection(context, stage),
      ],
    );
  }

  List<Widget> _stageSection(BuildContext context, StudyStage stage) {
    final stageGrades = studyGradesInStage(grades, stage);
    if (stageGrades.isEmpty) return const <Widget>[];

    return [
      SectionHeader(title: stage.label, icon: _stageIcon(stage)),
      const SizedBox(height: ZakerSpacing.sm),
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
              for (final grade in stageGrades)
                SizedBox(
                  width: width,
                  child: _GradeCard(
                    grade: grade,
                    stage: stage,
                    read: read,
                    onTap: () =>
                        context.push(ZakerRoutes.libraryPath(grade.id)),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: ZakerSpacing.xl),
    ];
  }
}

IconData _stageIcon(StudyStage stage) => switch (stage) {
  StudyStage.primary => Icons.child_care_rounded,
  StudyStage.preparatory => Icons.school_rounded,
  StudyStage.secondary => Icons.workspace_premium_rounded,
};

Color _stageColor(StudyStage stage) => switch (stage) {
  StudyStage.primary => const Color(0xFF0891B2),
  StudyStage.preparatory => const Color(0xFF7C3AED),
  StudyStage.secondary => const Color(0xFF0F766E),
};

/// The teal hero card at the top of the library.
class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.grades,
    required this.books,
    required this.lessons,
  });

  final int grades;
  final int books;
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
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF115E59)],
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
                        Icons.local_library_rounded,
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
                            'المكتبة الدراسية',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TrText(
                            'كل كتب المنهج في مكان واحد — من أولى ابتدائي '
                            'لتالتة ثانوي',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.lg),
                Row(
                  children: [
                    _GlassStat(
                      value: '$grades',
                      label: 'صف',
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    _GlassStat(
                      value: '$books',
                      label: 'كتاب',
                      icon: Icons.menu_book_outlined,
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

/// One grade card.
class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.stage,
    required this.read,
    required this.onTap,
  });

  final Grade grade;
  final StudyStage stage;
  final Set<String> read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _stageColor(stage);
    final subjects = studySubjects(grade, read);
    final progress = studyProgress(grade, read);
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
                accent.withValues(alpha: isDark ? 0.26 : 0.12),
                theme.cardTheme.color ?? Colors.white,
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.32 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
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
                          colors: [accent, accent.withValues(alpha: 0.72)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _stageIcon(stage),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  grade.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  '${subjects.length} مادة · ${grade.books.length} كتاب',
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
                  '${studyLessonCount(grade)} درس',
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
