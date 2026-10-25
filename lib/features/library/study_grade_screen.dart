/// A single grade inside «المكتبة الدراسية»: its subjects and progress.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/official_subject_index.dart';
import '../../core/router.dart';
import '../../core/study_library.dart';
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../models/official_book.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Lists the subjects derived from one grade's bundled books.
class StudyGradeScreen extends ConsumerWidget {
  const StudyGradeScreen({super.key, required this.gradeId});

  final String gradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradeAsync = ref.watch(gradeProvider(gradeId));
    final read = ref.watch(readLessonsProvider);
    final officialCatalog = ref.watch(officialBooksProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: TrText(kGradeLabels[gradeId] ?? gradeId)),
      body: gradeAsync.when(
        loading: () => const LoadingBox(label: 'بنفتح الصف…'),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مش قادرين نحمّل الصف',
          message: '$error',
        ),
        data: (grade) => _GradeBody(
          grade: grade,
          read: read,
          officialCatalog: officialCatalog,
        ),
      ),
    );
  }
}

class _GradeBody extends StatelessWidget {
  const _GradeBody({
    required this.grade,
    required this.read,
    required this.officialCatalog,
  });

  final Grade grade;
  final Set<String> read;
  final OfficialBookCatalog? officialCatalog;

  @override
  Widget build(BuildContext context) {
    final subjects = studySubjects(
      grade,
      read,
      officialCatalog: officialCatalog,
    );
    final official = officialCountsForGrade(officialCatalog, grade.id);
    final stage = StudyStage.of(grade.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.sm,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        _GradeHeader(
          grade: grade,
          stage: stage,
          subjectCount: subjects.length,
          official: official,
        ),
        if (stage == StudyStage.secondary) ...[
          const SizedBox(height: ZakerSpacing.md),
          _SecondaryHubCard(gradeId: grade.id),
        ],
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(title: 'المواد', icon: Icons.auto_stories_rounded),
        if (subjects.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'مفيش مواد في الصف ده',
            message: 'الكتب لسه بتتضاف للصف ده.',
          )
        else
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
                        onTap: () => context.push(
                          ZakerRoutes.librarySubjectPath(
                            grade.id,
                            subject.name,
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

/// The grade's summary header.
class _GradeHeader extends StatelessWidget {
  const _GradeHeader({
    required this.grade,
    required this.stage,
    required this.subjectCount,
    required this.official,
  });

  final Grade grade;
  final StudyStage? stage;
  final int subjectCount;
  final OfficialGradeCounts official;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF115E59)],
        ),
        boxShadow: [
          BoxShadow(
            color: ZakerColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(ZakerRadius.pill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: TrText(
                stage!.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            grade.label,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          TrText(
            'كل مواد الصف وكتبها في مكان واحد',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              _GlassStat(
                value: '$subjectCount',
                label: 'مادة',
                icon: Icons.auto_stories_outlined,
              ),
              _GlassStat(
                value: '${grade.books.length}',
                label: 'كتاب',
                icon: Icons.menu_book_outlined,
              ),
              _GlassStat(
                value: '${studyLessonCount(grade)}',
                label: 'درس',
                icon: Icons.play_lesson_outlined,
              ),
              if (!official.isEmpty)
                _GlassStat(
                  value: '${official.sources}',
                  label: 'مصدر رسمي',
                  icon: Icons.verified_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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

/// Entry point to the richer secondary curriculum hub (tracks/branches).
class _SecondaryHubCard extends StatelessWidget {
  const _SecondaryHubCard({required this.gradeId});

  final String gradeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        onTap: () => context.push(
          '${ZakerRoutes.subjects}?grade=${Uri.encodeQueryComponent(gradeId)}',
        ),
        child: Ink(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZakerRadius.lg),
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'منهج الثانوي',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TrText(
                      'الشعب والمسارات والمواد التفصيلية',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A subject card aggregated from the grade's books.
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.onTap});

  final StudySubjectSummary subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentInk = readableTextColor(
      subject.color,
      theme.cardTheme.color ?? theme.colorScheme.surface,
    );

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
                      child: Icon(subject.icon, color: Colors.white, size: 20),
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
                  subject.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  subject.isOfficialOnly
                      ? _officialLabel(subject)
                      : '${subject.lessons} درس · ${subject.books} كتاب',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
                if (subject.hasOfficial && !subject.isOfficialOnly) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 11, color: accentInk),
                      const SizedBox(width: 3),
                      Expanded(
                        child: TrText(
                          _officialLabel(subject),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accentInk,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (subject.lessons > 0) ...[
                  const SizedBox(height: ZakerSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: ProgressBar(
                          value: subject.progress,
                          height: 5,
                          color: subject.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${subject.percent}%',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accentInk,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The official availability line on a subject card.
String _officialLabel(StudySubjectSummary subject) {
  final parts = <String>[
    if (subject.officialBooks > 0) '${subject.officialBooks} كتاب رسمي',
    if (subject.officialAssessments > 0)
      '${subject.officialAssessments} تقييم رسمي',
  ];
  return parts.join(' · ');
}
