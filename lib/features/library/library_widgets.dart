/// Reusable widgets for the «المكتبة الدراسية» screens.
library;

import 'package:flutter/material.dart';

import '../../core/study_library.dart';
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

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
                    TrText(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
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
class BookSearchDelegate extends SearchDelegate<Book?> {
  BookSearchDelegate(this.grades) : super(searchFieldLabel: 'ابحث عن كتاب…');

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
              padding: const EdgeInsets.only(right: ZakerSpacing.xs, bottom: 2),
              child: TrText(
                match.grade,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            BookTile(book: match.book, onTap: () => close(context, match.book)),
          ],
        );
      },
    );
  }
}
