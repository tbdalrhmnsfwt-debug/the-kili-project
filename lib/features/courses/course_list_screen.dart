/// The courses tab: pick a grade, then a subject, then a book.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../lesson/book_lessons_screen.dart';

/// Grade labels, in the order the app shows them.
const Map<String, String> kGradeLabels = {
  'prep1': 'أولى إعدادي',
  'prep2': 'تانية إعدادي',
  'prep3': 'تالتة إعدادي',
  'prim1': 'أولى ابتدائي',
  'prim2': 'تانية ابتدائي',
  'prim3': 'تالتة ابتدائي',
  'prim4': 'رابعة ابتدائي',
  'prim5': 'خامسة ابتدائي',
  'prim6': 'سادسة ابتدائي',
  'sec1': 'أولى ثانوي',
  'sec2': 'تانية ثانوي',
  'sec3': 'تالتة ثانوي',
};

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
        const SnackBar(content: Text('لسه بنحمّل الكتب — جرّب تاني بعد لحظة.')),
      );
      return;
    }
    final book = await showSearch<Book?>(
      context: context,
      delegate: _BookSearchDelegate(grades),
    );
    if (book == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BookLessonsScreen(gradeId: book.grade, bookId: book.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradesAsync = ref.watch(gradesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المواد'),
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
            label: Text(entry.value),
            selected: isSelected,
            onSelected: (_) => onChanged(entry.key),
          );
        },
      ),
    );
  }
}

/// A single book in the list.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.onTap});

  final Book book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZakerRadius.sm),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${book.subject} • ${book.pages} صفحة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searches the titles and subjects of every book in every grade.
class _BookSearchDelegate extends SearchDelegate<Book?> {
  _BookSearchDelegate(this.grades) : super(searchFieldLabel: 'ابحث عن كتاب…');

  final List<Grade> grades;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'مسح',
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'رجوع',
    icon: const BackButtonIcon(),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final term = query.trim();
    if (term.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'دوّر على كتاب',
        message: 'اكتب اسم الكتاب أو المادة.',
      );
    }

    final matches = <({String grade, Book book})>[];
    for (final grade in grades) {
      for (final book in grade.books) {
        final hit =
            book.title.contains(term) ||
            book.subject.contains(term) ||
            book.variant.contains(term);
        if (hit) {
          matches.add((
            grade: kGradeLabels[grade.id] ?? grade.label,
            book: book,
          ));
        }
      }
    }

    if (matches.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'مفيش نتايج',
        message: 'مفيش كتاب فيه «$term». جرّب كلمة تانية.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: ZakerSpacing.sm),
      itemBuilder: (context, index) {
        final match = matches[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                right: ZakerSpacing.xs,
                bottom: 2,
              ),
              child: Text(
                match.grade,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            BookTile(
              book: match.book,
              onTap: () => close(context, match.book),
            ),
          ],
        );
      },
    );
  }
}
