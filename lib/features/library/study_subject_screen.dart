/// One subject inside «المكتبة الدراسية»: its bundled books and the official
/// catalog entries (which ship empty and show a pending state until filled).
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
import '../../providers/official_library_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'official_book_opener.dart';
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
    final theme = Theme.of(context);
    final officialAsync = ref.watch(officialBooksProvider);
    final official = officialRowsForSubject(
      officialAsync.valueOrNull,
      gradeId,
      subject,
    );

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
          official: official,
        ),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(
          title: 'الكتب الرسمية',
          icon: Icons.verified_outlined,
        ),
        if (official.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: ZakerSpacing.sm),
            child: TrText(
              _officialTermSummary(official),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        officialAsync.when(
          loading: () => const LoadingBox(label: 'بنقرا فهرس الوزارة…'),
          error: (error, _) => _OfficialPendingCard(
            message: 'مش قادرين نقرا الفهرس الرسمي دلوقتي: $error',
          ),
          data: (_) {
            if (official.isEmpty) {
              return const _OfficialPendingCard(
                message:
                    'مفيش كتب رسمية مربوطة بالمادة دي في فهرس ٢٠٢٦–٢٠٢٧. '
                    'مش هنخترع رابط بديل.',
              );
            }
            return Column(
              children: [
                for (final book in official) _OfficialBookTile(book: book),
              ],
            );
          },
        ),
        if (books.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: 'الكتب المتاحة',
            icon: Icons.menu_book_rounded,
          ),
          for (final book in books)
            BookTile(
              book: book,
              onTap: () => context.push(ZakerRoutes.lessonPath(book)),
            ),
        ] else if (official.isEmpty) ...[
          const SizedBox(height: ZakerSpacing.xl),
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'مفيش كتاب للمادة دي',
            message: 'جرّب مادة تانية من نفس الصف.',
          ),
        ],
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
    required this.official,
  });

  final String subject;
  final int books;
  final int lessons;
  final int readLessons;
  final List<OfficialBook> official;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = studySubjectVisual(subject);
    final progress = lessons == 0 ? 0.0 : readLessons / lessons;
    final percent = (progress * 100).round();
    final officialBooks = official
        .where(
          (book) =>
              book.hasDownload &&
              book.resourceKind != OfficialResourceKind.assessment,
        )
        .length;
    final officialAssessments = official
        .where(
          (book) =>
              book.hasDownload &&
              book.resourceKind == OfficialResourceKind.assessment,
        )
        .length;
    final onlyOfficial = books == 0 && official.isNotEmpty;

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
                      onlyOfficial
                          ? _officialHeaderLabel(
                              officialBooks,
                              officialAssessments,
                            )
                          : '$books كتاب · $lessons درس',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lessons > 0) ...[
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
                Expanded(
                  child: TrText(
                    'خلصت $readLessons من $lessons درس',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.sm),
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
          ] else if (onlyOfficial)
            Padding(
              padding: const EdgeInsets.only(top: ZakerSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TrText(
                      'من فهرس وزارة التربية والتعليم ٢٠٢٦–٢٠٢٧',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
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

/// A one-line, data-derived summary of the semesters in [rows].
String _officialTermSummary(List<OfficialBook> rows) {
  final terms = rows.map((book) => book.term).toSet();
  final String term;
  if (terms.length == 1) {
    term = terms.single.label;
  } else if (terms.contains(BookTerm.fullYear)) {
    term = BookTerm.fullYear.label;
  } else if (terms.containsAll(const {BookTerm.first, BookTerm.second})) {
    term = 'الفصلان الدراسيان';
  } else {
    term = 'أكثر من فصل دراسي';
  }
  final available = rows.where((book) => book.hasDownload).length;
  return available == rows.length
      ? '$term · ${rows.length} مصدر رسمي'
      : '$term · $available متاح من ${rows.length} مصدر';
}

/// The header line for a subject that exists only in the official catalog.
String _officialHeaderLabel(int books, int assessments) {
  final parts = <String>[
    if (books > 0) '$books كتاب رسمي',
    if (assessments > 0) '$assessments تقييم رسمي',
  ];
  return parts.isEmpty ? 'مصادر رسمية' : parts.join(' · ');
}

/// Shown when the official catalog has no entry for this grade and subject.
///
/// Deliberately offers no link: an invented URL would be worse than none.
class _OfficialPendingCard extends StatelessWidget {
  const _OfficialPendingCard({required this.message});

  final String message;

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
                  message,
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

/// One catalog entry, opened directly in the embedded PDF reader.
///
/// The info action stays available for the book's metadata and study tools,
/// but the tile itself never dead-ends: a verified row either opens its cached
/// file or shows live download progress before the reader.
class _OfficialBookTile extends ConsumerWidget {
  const _OfficialBookTile({required this.book});

  final OfficialBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(officialLibraryControllerProvider);
    final view = async.valueOrNull;
    final unavailable = async.hasError && view == null;
    final local = view?.stateOf(book) ?? book.initialState();
    final progress = view?.progress[book.id];
    final status = local.downloadStatus;
    final downloaded = status == BookDownloadStatus.downloaded;
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    final metadata = <String>[
      book.system.shortLabel,
      book.resourceKind.label,
      book.status.label,
      if (book.term != BookTerm.first) book.term.label,
    ].join(' · ');

    final fileLine = downloaded && local.fileSize > 0
        ? '${formatOfficialFileSize(local.fileSize)}'
              '${local.pageCount > 0 ? ' · ${local.pageCount} صفحة' : ''}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: ListTile(
        leading: Icon(
          switch (status) {
            _ when unavailable => Icons.error_outline_rounded,
            BookDownloadStatus.downloaded => Icons.download_done_rounded,
            BookDownloadStatus.downloading ||
            BookDownloadStatus.queued => Icons.downloading_rounded,
            BookDownloadStatus.failed => Icons.error_outline_rounded,
            _ when !book.hasDownload => Icons.lock_clock_outlined,
            _ => Icons.picture_as_pdf_outlined,
          },
          color: switch (status) {
            _ when unavailable => ZakerColors.danger,
            BookDownloadStatus.downloaded => ZakerColors.success,
            BookDownloadStatus.failed => ZakerColors.danger,
            _ when !book.hasDownload => readableTextColor(
              ZakerColors.accent,
              cardColor,
            ),
            _ => theme.colorScheme.primary,
          },
        ),
        title: TrText(
          book.titleAr,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(metadata, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (fileLine.isNotEmpty)
              TrText(
                fileLine,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (progress != null || status.isBusy)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress?.fraction,
                    minHeight: 4,
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'تفاصيل الكتاب وأدوات المذاكرة',
          icon: const Icon(Icons.info_outline_rounded, size: 20),
          onPressed: () => context.push(ZakerRoutes.officialBookPath(book.id)),
        ),
        onTap: () => openOfficialBook(context, ref, book),
      ),
    );
  }
}
