/// The courses tab: pick a grade, then a subject, then a book.
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
import '../home/shell_screen.dart';
import '../lesson/book_lessons_screen.dart';
import '../library/library_widgets.dart';
import '../../widgets/tr_text.dart';

/// The courses list screen.
class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key, this.gradeId});

  /// When set, the screen opens on this grade instead of the stored one.
  final String? gradeId;

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  String? _subject;

  String get _gradeId => widget.gradeId ?? ref.read(selectedGradeProvider);

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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookLessonsScreen(gradeId: book.grade, bookId: book.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradesAsync = ref.watch(gradesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuLeading(context),
        title: const TrText('المواد'),
        actions: [
          IconButton(
            tooltip: 'ابحث في كل الكتب',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _search(context, gradesAsync.valueOrNull),
          ),
        ],
      ),
      body: gradesAsync.when(
        loading: () => const LoadingBox(),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'مفيش مواد',
          message: '$e',
        ),
        data: (grades) {
          final grade = grades.firstWhere(
            (g) => g.id == _gradeId,
            orElse: () => Grade(
              id: _gradeId,
              label: kGradeLabels[_gradeId] ?? _gradeId,
              books: const [],
            ),
          );
          final subjects = grade.books.map((b) => b.subject).toSet().toList()
            ..sort();
          final books = _subject == null
              ? grade.books
              : grade.books.where((b) => b.subject == _subject).toList();

          return Column(
            children: [
              _CurriculumBanner(gradeId: _gradeId),
              _GradeSelector(
                selected: _gradeId,
                onChanged: (id) {
                  setState(() => _subject = null);
                  ref.read(selectedGradeProvider.notifier).state = id;
                },
              ),
              if (subjects.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ChipStrip(
                    items: subjects,
                    selected: _subject,
                    onSelected: (s) =>
                        setState(() => _subject = s == _subject ? null : s),
                  ),
                ),
              const SizedBox(height: ZakerSpacing.sm),
              Expanded(
                child: books.isEmpty
                    ? const EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'مفيش كتب هنا',
                        message: 'اختار تاني مادة أو مستوى.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          ZakerSpacing.lg,
                          0,
                          ZakerSpacing.lg,
                          ZakerSpacing.xxl,
                        ),
                        itemCount: books.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: ZakerSpacing.md),
                        itemBuilder: (context, index) => BookTile(
                          book: books[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BookLessonsScreen(
                                gradeId: _gradeId,
                                bookId: books[index].id,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A prominent entry point to the secondary curriculum hub.
class _CurriculumBanner extends StatelessWidget {
  const _CurriculumBanner({required this.gradeId});

  final String gradeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.sm,
        ZakerSpacing.lg,
        0,
      ),
      child: Material(
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
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: ZakerColors.navyGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
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
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TrText(
                        'مواد أولى وتانية وتالتة ثانوي — اختار شعبتك أو مسارك',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal grade picker.
class _GradeSelector extends StatelessWidget {
  const _GradeSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.lg,
          vertical: ZakerSpacing.sm,
        ),
        itemCount: kGradeLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZakerSpacing.sm),
        itemBuilder: (context, index) {
          final entry = kGradeLabels.entries.elementAt(index);
          final isSelected = entry.key == selected;
          return ChoiceChip(
            label: TrText(entry.value),
            selected: isSelected,
            onSelected: (_) => onChanged(entry.key),
          );
        },
      ),
    );
  }
}
