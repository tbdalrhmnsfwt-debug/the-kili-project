/// Reading a book: its lesson list, and a lesson's content blocks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/asset_service.dart';
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import 'lesson_reader_screen.dart';
import '../../widgets/tr_text.dart';

/// Lists the lessons of a book.
class BookLessonsScreen extends ConsumerWidget {
  const BookLessonsScreen({
    super.key,
    required this.gradeId,
    required this.bookId,
  });

  final String gradeId;
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradeAsync = ref.watch(gradeProvider(gradeId));

    return Scaffold(
      appBar: AppBar(title: const TrText('الدروس')),
      body: gradeAsync.when(
        loading: () => const LoadingBox(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مقدرناش نفتح الكتاب',
          message: '$e',
        ),
        data: (grade) {
          final book = grade.books.firstWhere(
            (b) => b.id == bookId,
            orElse: () => const Book(
              id: '',
              subject: '',
              variant: '',
              lang: 'ar',
              title: '',
              pages: 0,
              lessons: 0,
              grade: '',
              file: '',
              fingerprint: '',
            ),
          );
          return _LessonsList(gradeId: gradeId, book: book);
        },
      ),
    );
  }
}

class _LessonsList extends ConsumerWidget {
  const _LessonsList({required this.gradeId, required this.book});

  final String gradeId;
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lessonsAsync = ref.watch(lessonsProvider(book));

    return lessonsAsync.when(
      loading: () => const LoadingBox(),
      error: (e, _) => EmptyState(
        icon: Icons.lock_outline_rounded,
        title: e is BookContentUnavailable
            ? 'الكتاب مش متاح للقراءة'
            : 'مش قادرين نفتح الكتاب',
        message: e is BookContentUnavailable
            ? 'نسخة الكتاب دي محتواها مشفّر ومش بيتقرأ على الجهاز. '
                  'جرّب كتاب تاني من نفس الصف.'
            : 'الملف مش متاح على الجهاز.\n$e',
      ),
      data: (lessons) {
        if (lessons.isEmpty) {
          return const EmptyState(
            icon: Icons.list_alt_rounded,
            title: 'مفيش دروس',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: ZakerSpacing.sm),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(ZakerRadius.md),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LessonReaderScreen(
                      gradeId: gradeId,
                      book: book,
                      lesson: lesson,
                    ),
                  ),
                ),
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
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: TrText(
                          '${lesson.number}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZakerSpacing.md),
                      Expanded(
                        child: TrText(
                          lesson.title.isEmpty
                              ? 'الدرس ${lesson.number}'
                              : lesson.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
