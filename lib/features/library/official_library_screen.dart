/// The official 2026–2027 study library.
///
/// Unlike the bundled «المكتبة الدراسية», this screen lists the Ministry's
/// published books and assessments with their real status. It never presents
/// a book as compulsory: the General Secondary index does not encode streams,
/// so its rows are labelled «غير محددة في الفهرس الرسمي».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/book_download_service.dart';
import '../../models/official_book.dart';
import '../../providers/app_providers.dart';
import '../../providers/official_library_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Lists official books by system, grade, pathway and subject.
class OfficialLibraryScreen extends ConsumerStatefulWidget {
  const OfficialLibraryScreen({super.key});

  @override
  ConsumerState<OfficialLibraryScreen> createState() =>
      _OfficialLibraryScreenState();
}

class _OfficialLibraryScreenState extends ConsumerState<OfficialLibraryScreen> {
  EducationSystem _system = EducationSystem.generalSecondary;
  String _grade = 'sec1';
  BaccalaureatePathway _pathway = BaccalaureatePathway.none;
  OfficialResourceKind? _kind;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(officialBooksProvider);
    final libraryAsync = ref.watch(officialLibraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('المكتبة الرسمية'),
        actions: [
          libraryAsync.when(
            data: (view) => IconButton(
              tooltip: 'افحص ملفات الكتب على الجهاز',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref
                  .read(officialLibraryControllerProvider.notifier)
                  .refreshFromDisk(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const LoadingBox(label: 'بنقرا فهرس الكتب الرسمية…'),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'مش قادرين نحمّل الفهرس الرسمي',
          message:
              'الفهرس محفوظ جوه التطبيق. جرّب تعيد فتح الصفحة.\n$error',
        ),
        data: (catalog) {
          if (catalog.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'الفهرس الرسمي فاضي',
              message: 'ملف الفهرس المرافق للتطبيق مفيهوش كتب.',
            );
          }
          final view = libraryAsync.valueOrNull;
          final books = _filtered(catalog);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.sm,
              ZakerSpacing.lg,
              ZakerSpacing.xxl,
            ),
            children: [
              _OfficialHero(
                catalog: catalog,
                downloaded: view?.downloadedCount ?? 0,
                ready: view?.readyCount ?? 0,
              ),
              if (libraryAsync.hasError)
                _WarningCard(
                  message:
                      'حالة التنزيل مش متاحة دلوقتي: '
                      '${libraryAsync.error}',
                ),
              if (view != null && view.recoveredFromBackup)
                _WarningCard(
                  message:
                      'اتصلح ملف المكتبة من نسخة احتياطية. راجع حالة الكتب.',
                ),
              if (view != null && view.notice.isNotEmpty)
                _NoticeCard(text: view.notice),
              const SizedBox(height: ZakerSpacing.lg),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الكتاب أو المادة…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'امسح البحث',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              _SystemSelector(
                value: _system,
                onChanged: (system) => setState(() {
                  _system = system;
                  _pathway = BaccalaureatePathway.none;
                  if (system == EducationSystem.egyptianBaccalaureate &&
                      _grade == 'sec1') {
                    _grade = 'sec2';
                  }
                }),
              ),
              const SizedBox(height: ZakerSpacing.sm),
              _GradeChips(
                catalog: catalog,
                system: _system,
                value: _grade,
                onChanged: (grade) => setState(() => _grade = grade),
              ),
              if (_system == EducationSystem.egyptianBaccalaureate) ...[
                const SizedBox(height: ZakerSpacing.sm),
                _PathwayChips(
                  value: _pathway,
                  onChanged: (pathway) => setState(() => _pathway = pathway),
                ),
              ],
              const SizedBox(height: ZakerSpacing.sm),
              _KindChips(
                value: _kind,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: ZakerSpacing.lg),
              if (books.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'مفيش نتايج',
                  message:
                      'جرّب تغيّر الصف أو المسار، أو اكتب جزء من اسم الكتاب.',
                )
              else
                ..._grouped(books, view),
              const SizedBox(height: ZakerSpacing.xl),
              _SourcesFooter(catalog: catalog),
            ],
          );
        },
      ),
    );
  }

  List<OfficialBook> _filtered(OfficialBookCatalog catalog) {
    final query = normalizeArabic(_query).toLowerCase().trim();
    final rows = catalog.books.where((book) {
      if (book.grade != _grade) return false;
      if (book.system != _system) return false;
      if (_system == EducationSystem.egyptianBaccalaureate &&
          _pathway != BaccalaureatePathway.none &&
          book.track != BaccalaureatePathway.none &&
          book.track != _pathway) {
        return false;
      }
      if (_kind != null && book.resourceKind != _kind) return false;
      if (query.isNotEmpty) {
        final haystack = normalizeArabic(
          '${book.titleAr} ${book.subject} ${book.fileName}',
        ).toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
    rows.sort((a, b) {
      if (a.isNotice != b.isNotice) return a.isNotice ? 1 : -1;
      final kind = a.resourceKind.index.compareTo(b.resourceKind.index);
      if (kind != 0) return kind;
      final subject = normalizeSubject(a.subject).compareTo(
        normalizeSubject(b.subject),
      );
      if (subject != 0) return subject;
      return a.titleAr.compareTo(b.titleAr);
    });
    return rows;
  }

  List<Widget> _grouped(List<OfficialBook> books, OfficialLibraryViewState? view) {
    final widgets = <Widget>[];
    String? subject;
    for (final book in books) {
      final key = normalizeSubject(book.subject);
      if (key != subject) {
        subject = key;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: ZakerSpacing.md, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                TrText(
                  key.isEmpty ? 'مواد أخرى' : key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(
        _OfficialBookRow(
          book: book,
          localState: view?.stateOf(book) ?? book.initialState(),
          progress: view?.progress[book.id],
          extractionFraction: view?.extractionProgress[book.id],
          onTap: () => context.push(ZakerRoutes.officialBookPath(book.id)),
        ),
      );
    }
    return widgets;
  }
}

class _OfficialHero extends StatelessWidget {
  const _OfficialHero({
    required this.catalog,
    required this.downloaded,
    required this.ready,
  });

  final OfficialBookCatalog catalog;
  final int downloaded;
  final int ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = catalog.books.where((book) => book.isPublished).length;
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
            color: ZakerColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                        Icons.verified_rounded,
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
                            'الكتب الرسمية ${catalog.schoolYear}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TrText(
                            'روابط منشورة على صفحات وزارة التربية والتعليم. '
                            'مفيش روابط مخترعة.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.lg),
                Wrap(
                  spacing: ZakerSpacing.sm,
                  runSpacing: ZakerSpacing.sm,
                  children: [
                    _HeroStat(value: '$available', label: 'متاح رسميًا'),
                    _HeroStat(value: '$downloaded', label: 'منزّل عندك'),
                    _HeroStat(value: '$ready', label: 'جاهز للمذاكرة'),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

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
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 5),
          TrText(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemSelector extends StatelessWidget {
  const _SystemSelector({required this.value, required this.onChanged});

  final EducationSystem value;
  final ValueChanged<EducationSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<EducationSystem>(
      segments: const [
        ButtonSegment(
          value: EducationSystem.generalSecondary,
          label: Text('الثانوي العام'),
          icon: Icon(Icons.school_outlined),
        ),
        ButtonSegment(
          value: EducationSystem.egyptianBaccalaureate,
          label: Text('البكالوريا المصرية'),
          icon: Icon(Icons.workspace_premium_outlined),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _GradeChips extends StatelessWidget {
  const _GradeChips({
    required this.catalog,
    required this.system,
    required this.value,
    required this.onChanged,
  });

  final OfficialBookCatalog catalog;
  final EducationSystem system;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final grades = <String>['sec1', 'sec2', 'sec3'];
    final counts = <String, int>{};
    for (final book in catalog.books) {
      if (book.system != system) continue;
      counts[book.grade] = (counts[book.grade] ?? 0) + 1;
    }
    return Wrap(
      spacing: ZakerSpacing.sm,
      runSpacing: ZakerSpacing.sm,
      children: [
        for (final grade in grades)
          ChoiceChip(
            label: Text('${gradeLabels[grade] ?? grade}'
                '${counts[grade] == null ? '' : ' · ${counts[grade]}'}'),
            selected: value == grade,
            onSelected: (_) => onChanged(grade),
          ),
      ],
    );
  }
}

class _PathwayChips extends StatelessWidget {
  const _PathwayChips({required this.value, required this.onChanged});

  final BaccalaureatePathway value;
  final ValueChanged<BaccalaureatePathway> onChanged;

  @override
  Widget build(BuildContext context) {
    final pathways = [
      BaccalaureatePathway.none,
      BaccalaureatePathway.medicineLifeSciences,
      BaccalaureatePathway.engineeringComputerScience,
      BaccalaureatePathway.business,
      BaccalaureatePathway.artsHumanities,
    ];
    return Wrap(
      spacing: ZakerSpacing.sm,
      runSpacing: ZakerSpacing.sm,
      children: [
        for (final pathway in pathways)
          FilterChip(
            label: Text(
              pathway == BaccalaureatePathway.none ? 'كل المسارات' : pathway.label,
            ),
            selected: value == pathway,
            onSelected: (_) => onChanged(pathway),
          ),
      ],
    );
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips({required this.value, required this.onChanged});

  final OfficialResourceKind? value;
  final ValueChanged<OfficialResourceKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: ChoiceChip(
              label: const Text('كل المصادر'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final kind in [
            OfficialResourceKind.studentBook,
            OfficialResourceKind.assessment,
            OfficialResourceKind.story,
            OfficialResourceKind.workbook,
            OfficialResourceKind.activity,
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: ChoiceChip(
                label: Text(kind.label),
                selected: value == kind,
                onSelected: (_) => onChanged(kind),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfficialBookRow extends StatelessWidget {
  const _OfficialBookRow({
    required this.book,
    required this.localState,
    required this.progress,
    required this.extractionFraction,
    required this.onTap,
  });

  final OfficialBook book;
  final BookLocalState localState;
  final DownloadProgress? progress;
  final double? extractionFraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = localState.downloadStatus;
    final accent = switch (book.status) {
      OfficialBookStatus.available => theme.colorScheme.primary,
      OfficialBookStatus.notPublished => ZakerColors.accent,
      OfficialBookStatus.manualReview => ZakerColors.accent,
      OfficialBookStatus.retired => theme.colorScheme.onSurfaceVariant,
    };
    final subtitle = switch (status) {
      BookDownloadStatus.downloaded =>
        '${_size(localState.fileSize)} · ${_extractionLabel(localState.extractionStatus)}',
      BookDownloadStatus.downloading =>
        'بيتنزّل ${progress?.fraction == null ? '' : '· ${progress!.percent}%'}',
      BookDownloadStatus.queued => 'في انتظار التنزيل',
      BookDownloadStatus.needsUpdate => 'فيه نسخة أحدث على السيرفر الرسمي',
      BookDownloadStatus.failed => 'فشل التنزيل — اضغط للتفاصيل',
      _ => '${book.resourceKind.label} · ${book.languageLabel} · ${book.term.label}',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.md,
          vertical: 2,
        ),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon(book.resourceKind), color: accent, size: 21),
        ),
        title: TrText(
          book.titleAr,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TrText(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: status == BookDownloadStatus.downloading
            ? SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress?.fraction,
                  strokeWidth: 3,
                ),
              )
            : extractionFraction != null
            ? SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: extractionFraction,
                  strokeWidth: 3,
                ),
              )
            : Icon(
                book.isPublished
                    ? (localState.isReadyForLearning
                          ? Icons.check_circle_rounded
                          : Icons.chevron_left_rounded)
                    : Icons.lock_clock_rounded,
                size: 20,
                color: localState.isReadyForLearning
                    ? ZakerColors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  static IconData _icon(OfficialResourceKind kind) => switch (kind) {
    OfficialResourceKind.studentBook => Icons.menu_book_rounded,
    OfficialResourceKind.assessment => Icons.assignment_outlined,
    OfficialResourceKind.story => Icons.auto_stories_outlined,
    OfficialResourceKind.workbook => Icons.edit_note_rounded,
    OfficialResourceKind.activity => Icons.extension_outlined,
    OfficialResourceKind.notice => Icons.campaign_outlined,
    OfficialResourceKind.reference => Icons.library_books_outlined,
  };

  static String _size(int bytes) {
    if (bytes <= 0) return 'حجم غير معروف';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} ك.ب';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }

  static String _extractionLabel(BookExtractionStatus status) => switch (status) {
    BookExtractionStatus.ready => 'جاهز للمذاكرة',
    BookExtractionStatus.needsReview => 'نص مستخرج · يحتاج مراجعة',
    BookExtractionStatus.extracting => 'بيستخرج النص',
    BookExtractionStatus.organizing => 'بيرتّب الدروس',
    BookExtractionStatus.failed => 'الاستخراج فشل',
    BookExtractionStatus.notStarted => 'منزّل · لسه مااتاستخرجش',
  };
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: Icons.warning_amber_rounded,
      color: ZakerColors.accent,
      text: message,
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: Icons.info_outline_rounded,
      color: Theme.of(context).colorScheme.primary,
      text: text,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: TrText(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter({required this.catalog});

  final OfficialBookCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: ZakerSpacing.md),
      leading: Icon(
        Icons.source_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: const TrText('مصادر الفهرس الرسمي'),
      subtitle: TrText(
        '${catalog.sources.length} صفحة رسمية · آخر تحديث ${catalog.updated}',
        style: theme.textTheme.labelSmall,
      ),
      children: [
        for (final source in catalog.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.link_rounded, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: TrText(
                    '${source.title}\n${source.url}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (catalog.notes.isNotEmpty)
          TrText(
            catalog.notes,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
          ),
      ],
    );
  }
}
