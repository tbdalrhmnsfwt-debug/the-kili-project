/// One subject inside «المكتبة الدراسية»: its bundled books and the official
/// catalog entries (which ship empty and show a pending state until filled).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/study_library.dart';
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../models/official_book.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'library_widgets.dart';

/// Lists one subject's books for a grade, plus the official-book catalog.
class StudySubjectScreen extends ConsumerWidget {
  const StudySubjectScreen({
    super.key,
    required this.gradeId,
    required this.subject,
  });

  final String gradeId;
  final String subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradeAsync = ref.watch(gradeProvider(gradeId));
    final read = ref.watch(readLessonsProvider);

    return Scaffold(
      appBar: AppBar(title: TrText(subject)),
      body: gradeAsync.when(
        loading: () => const LoadingBox(label: 'بنفتح المادة…'),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مش قادرين نحمّل المادة',
          message: '$error',
        ),
        data: (grade) {
          final books = grade.books
              .where((book) => book.subject == subject)
              .toList(growable: false);
          return _SubjectBody(
            gradeId: gradeId,
            subject: subject,
            books: books,
            read: read,
          );
        },
      ),
    );
  }
}

class _SubjectBody extends ConsumerWidget {
  const _SubjectBody({
    required this.gradeId,
    required this.subject,
    required this.books,
    required this.read,
  });

  final String gradeId;
  final String subject;
  final List<Book> books;
  final Set<String> read;

  int get _lessons => books.fold<int>(0, (sum, book) => sum + book.lessons);

  int get _readLessons {
    var count = 0;
    for (final book in books) {
      for (var lesson = 1; lesson <= book.lessons; lesson++) {
        if (read.contains('$gradeId/${book.id}/$lesson')) count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialAsync = ref.watch(officialBooksProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.sm,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        _SubjectHeader(
          subject: subject,
          books: books.length,
          lessons: _lessons,
          readLessons: _readLessons,
        ),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(
          title: 'الكتب الرسمية',
          icon: Icons.verified_outlined,
        ),
        officialAsync.when(
          loading: () => const LoadingBox(),
          error: (error, _) => const _OfficialPendingCard(),
          data: (catalog) {
            final official = catalog.forGradeSubject(gradeId, subject);
            if (official.isEmpty) return const _OfficialPendingCard();
            return Column(
              children: [
                for (final book in official) _OfficialBookTile(book: book),
              ],
            );
          },
        ),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(
          title: 'الكتب المتاحة',
          icon: Icons.menu_book_rounded,
        ),
        if (books.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'مفيش كتاب للمادة دي',
            message: 'جرّب مادة تانية من نفس الصف.',
          )
        else
          for (final book in books)
            BookTile(
              book: book,
              onTap: () => context.push(ZakerRoutes.lessonPath(book)),
            ),
      ],
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({
    required this.subject,
    required this.books,
    required this.lessons,
    required this.readLessons,
  });

  final String subject;
  final int books;
  final int lessons;
  final int readLessons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = studySubjectVisual(subject);
    final progress = lessons == 0 ? 0.0 : readLessons / lessons;
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(visual.color, Colors.black, 0.3)!,
            visual.color.withValues(alpha: 0.85),
            const Color(0xFF115E59),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: visual.color.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZakerSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(visual.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TrText(
                      '$books كتاب · $lessons درس',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZakerRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TrText(
                'خلصت $readLessons من $lessons درس',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown while the official catalog has no entry for this grade and subject.
///
/// Deliberately offers no link: an invented URL would be worse than none.
class _OfficialPendingCard extends StatelessWidget {
  const _OfficialPendingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'البيانات الرسمية قيد الإضافة',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  'روابط الكتب الرسمية لسه بتتضاف. الكتب المتاحة فوق من '
                  'مكتبة المنهج المرفقة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One catalog entry, opened in the platform browser/pdf viewer.
class _OfficialBookTile extends StatelessWidget {
  const _OfficialBookTile({required this.book});

  final OfficialBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: ListTile(
        leading: Icon(
          book.isPublished
              ? Icons.picture_as_pdf_outlined
              : Icons.lock_clock_outlined,
          color: book.isPublished
              ? theme.colorScheme.primary
              : ZakerColors.accent,
        ),
        title: TrText(book.title),
        subtitle: TrText(
          '${book.resourceKind.label} · ${book.status.label}'
          '${book.term == BookTerm.first ? '' : ' · ${book.term.label}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          book.isPublished
              ? Icons.chevron_left_rounded
              : Icons.info_outline_rounded,
          size: 18,
        ),
        onTap: () => context.push(ZakerRoutes.officialBookPath(book.id)),
      ),
    );
  }
}
