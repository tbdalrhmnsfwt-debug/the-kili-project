/// One official book: metadata, verified download, extraction and lessons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/book_extraction.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/official_book.dart';
import '../../providers/app_providers.dart';
import '../../providers/official_library_providers.dart';
import '../tools/pdf_viewer_screen.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Shows one catalog row and everything done with it on this device.
class OfficialBookScreen extends ConsumerStatefulWidget {
  const OfficialBookScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<OfficialBookScreen> createState() => _OfficialBookScreenState();
}

class _OfficialBookScreenState extends ConsumerState<OfficialBookScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(officialBooksProvider).valueOrNull;
    final view = ref.watch(officialLibraryControllerProvider).valueOrNull;
    final book = _findBook(catalog);

    if (book == null) {
      final loading = ref.watch(officialBooksProvider).isLoading;
      return Scaffold(
        appBar: AppBar(title: const TrText('الكتاب الرسمي')),
        body: loading
            ? const LoadingBox(label: 'بنقرا بيانات الكتاب…')
            : const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'الكتاب مش موجود في الفهرس',
                message: 'الفهرس الرسمي المرافق للتطبيق مفيهوش الكتاب ده.',
              ),
      );
    }

    final local = view?.stateOf(book) ?? book.initialState();
    final extractedAsync = ref.watch(officialExtractedProvider(book.id));

    return Scaffold(
      appBar: AppBar(
        title: const TrText('الكتاب الرسمي'),
        actions: [
          if (local.hasFile)
            IconButton(
              tooltip: 'افتح ملف PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () => _openPdf(book, local),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.md,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          _BookHeader(book: book, local: local, onOpenSource: _openSource),
          if (view != null && view.notice.isNotEmpty)
            _InlineNotice(
              text: view.notice,
              onClose: () =>
                  ref.read(officialLibraryControllerProvider.notifier).clearNotice(),
            ),
          if (local.error.isNotEmpty && local.error != view?.notice)
            _InlineNotice(text: local.error, isError: true),
          if (local.duplicateOf.isNotEmpty)
            _InlineNotice(
              text:
                  'الملف ده مطابق لكتاب تاني على الجهاز (${local.duplicateOf})، '
                  'فمتخزنش مرتين. نفس الملف ونفس جاهزية المذاكرة.',
            ),
          const SizedBox(height: ZakerSpacing.lg),
          _DownloadPanel(
            book: book,
            local: local,
            view: view,
            onDownload: () => ref
                .read(officialLibraryControllerProvider.notifier)
                .requestDownload(book),
            onCancel: () => ref
                .read(officialLibraryControllerProvider.notifier)
                .cancelDownload(book),
            onCheck: () => ref
                .read(officialLibraryControllerProvider.notifier)
                .checkForUpdate(book),
            onOpen: () => _openPdf(book, local),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          if (!local.hasFile)
            _LockedTools(book: book)
          else
            _StudyToolsPanel(
              book: book,
              local: local,
              extractedAsync: extractedAsync,
              searchController: _searchController,
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onExtract: (ocr) => ref
                  .read(officialLibraryControllerProvider.notifier)
                  .extractBook(book, allowOcr: ocr),
              onOpenSection: (section) => context.push(
                ZakerRoutes.officialSectionPath(book.id, section.id),
              ),
              onOpenPage: (page) => _openPageInSection(extractedAsync.value, page),
            ),
          const SizedBox(height: ZakerSpacing.lg),
          _StorageDetails(local: local),
        ],
      ),
    );
  }

  OfficialBook? _findBook(OfficialBookCatalog? catalog) {
    if (catalog == null) return null;
    for (final book in catalog.books) {
      if (book.id == widget.bookId) return book;
    }
    return null;
  }

  void _openPdf(OfficialBook book, BookLocalState local) {
    if (!local.hasFile) return;
    context.push(
      PdfViewerScreen.location(local.filePath, title: book.titleAr),
    );
  }

  void _openPageInSection(ExtractedBook? extracted, int page) {
    if (extracted == null) return;
    for (final section in extracted.sections) {
      if (page >= section.startPage && page <= section.endPage) {
        context.push(
          ZakerRoutes.officialSectionPath(widget.bookId, section.id),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('الصفحة دي برّه الدروس المستخرجة.')),
    );
  }

  Future<void> _openSource(OfficialBook book) async {
    final raw = book.officialSourceUrl.isNotEmpty
        ? book.officialSourceUrl
        : book.sourcePage;
    if (raw.isEmpty) {
      _snack('مفيش رابط مصدر رسمي مسجّل للكتاب ده.');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.isScheme('https')) {
      _snack('رابط المصدر غير صالح. مفيش رابط بديل مخترع.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _snack('مش قادرين نفتح رابط المصدر الرسمي.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BookHeader extends StatelessWidget {
  const _BookHeader({
    required this.book,
    required this.local,
    required this.onOpenSource,
  });

  final OfficialBook book;
  final BookLocalState local;
  final Future<void> Function(OfficialBook) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = book.isPublished
        ? theme.colorScheme.primary
        : ZakerColors.accent;
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: 0.16),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                ),
                child: Icon(Icons.menu_book_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      book.titleAr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    if (book.titleEn.isNotEmpty)
                      TrText(
                        book.titleEn,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    TrText(
                      '${book.subject} · ${book.gradeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              _MetaChip(
                icon: Icons.account_balance_outlined,
                label: book.system.label,
              ),
              _MetaChip(
                icon: Icons.route_outlined,
                label: book.system == EducationSystem.generalSecondary
                    ? 'المسار غير محدد في الفهرس الرسمي'
                    : book.track.label,
              ),
              _MetaChip(
                icon: Icons.calendar_month_outlined,
                label: '${book.schoolYear} · ${book.term.label}',
              ),
              _MetaChip(
                icon: Icons.translate_rounded,
                label: book.languageLabel,
              ),
              _MetaChip(
                icon: Icons.label_outline_rounded,
                label: book.resourceKind.label,
              ),
              _MetaChip(
                icon: book.isPublished
                    ? Icons.verified_rounded
                    : Icons.lock_clock_rounded,
                label: book.status.label,
                tone: accent,
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          TrText(
            book.statusExplanation,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          if (book.sourceNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TrText(
                book.sourceNote,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: ZakerSpacing.sm),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => onOpenSource(book),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const TrText('صفحة المصدر الرسمية'),
              ),
              if (book.edition.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.bookmark_outline_rounded, size: 14),
                  label: TrText('طبعة ${book.edition}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = tone ?? theme.colorScheme.onSurfaceVariant;
    final color = readableTextColor(base, theme.colorScheme.surface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(color: base.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadPanel extends StatelessWidget {
  const _DownloadPanel({
    required this.book,
    required this.local,
    required this.view,
    required this.onDownload,
    required this.onCancel,
    required this.onCheck,
    required this.onOpen,
  });

  final OfficialBook book;
  final BookLocalState local;
  final OfficialLibraryViewState? view;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onCheck;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = local.downloadStatus;
    final progress = view?.progress[book.id];
    final canDownload = book.hasDownload && view != null;
    final busy = status.isBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status == BookDownloadStatus.downloaded
                      ? Icons.download_done_rounded
                      : Icons.cloud_download_outlined,
                  color: status == BookDownloadStatus.downloaded
                      ? ZakerColors.success
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: TrText(
                    'النسخة الرسمية على الجهاز',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: TrText(
                    status.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: status == BookDownloadStatus.failed
                          ? readableTextColor(
                              ZakerColors.danger,
                              theme.colorScheme.surface,
                            )
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: ZakerSpacing.md),
              LinearProgressIndicator(
                value: progress?.fraction ?? local.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              TrText(
                progress == null
                    ? 'بنحضّر التنزيل…'
                    : '${progress.percent}% · ${_size(progress.received)} من '
                          '${progress.total > 0 ? _size(progress.total) : 'حجم غير معروف'}',
                style: theme.textTheme.labelSmall,
              ),
            ],
            if (status == BookDownloadStatus.downloaded &&
                local.fileSize > 0) ...[
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                '${_size(local.fileSize)} · ${local.pageCount} صفحة'
                '${local.downloadedAt == null ? '' : ' · نُزّل ${_date(local.downloadedAt!)}'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (local.sha256.isNotEmpty)
                TrText(
                  'SHA-256: ${local.sha256.substring(0, local.sha256.length.clamp(0, 16))}…',
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
            const SizedBox(height: ZakerSpacing.md),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.sm,
              children: [
                if (busy)
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const TrText('إلغاء التنزيل'),
                  )
                else if (!book.hasDownload)
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: Text(book.status.label),
                  )
                else if (status == BookDownloadStatus.downloaded ||
                    status == BookDownloadStatus.needsUpdate)
                  ..._downloadedActions(context)
                else
                  FilledButton.icon(
                    onPressed: canDownload ? onDownload : null,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: TrText(_downloadLabel(status)),
                  ),
                if (book.hasDownload && !busy && status != BookDownloadStatus.downloaded)
                  TextButton.icon(
                    onPressed: canDownload ? onCheck : null,
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const TrText('افحص الرابط'),
                  ),
              ],
            ),
            if (!book.hasDownload)
              Padding(
                padding: const EdgeInsets.only(top: ZakerSpacing.sm),
                child: TrText(
                  'زميلنا مش هيفبرك رابط. لو الكتاب نزل رسميًا هيتضاف للفهرس '
                  'بعد مراجعة المصدر.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _downloadedActions(BuildContext context) => [
    FilledButton.icon(
      onPressed: onOpen,
      icon: const Icon(Icons.menu_book_rounded, size: 18),
      label: const TrText('افتح PDF'),
    ),
    OutlinedButton.icon(
      onPressed: view?.checkingUpdates == true ? null : onCheck,
      icon: view?.checkingUpdates == true
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded, size: 17),
      label: const TrText('افحص التحديث'),
    ),
    if (local.downloadStatus == BookDownloadStatus.needsUpdate)
      FilledButton.tonalIcon(
        onPressed: onDownload,
        icon: const Icon(Icons.system_update_rounded, size: 18),
        label: const TrText('نزّل النسخة الجديدة'),
      ),
  ];

  static String _downloadLabel(BookDownloadStatus status) => switch (status) {
    BookDownloadStatus.failed => 'جرّب التنزيل تاني',
    BookDownloadStatus.cancelled => 'كمّل التنزيل',
    BookDownloadStatus.queued => 'في الانتظار…',
    _ => 'نزّل من المصدر الرسمي',
  };
}

class _StudyToolsPanel extends StatelessWidget {
  const _StudyToolsPanel({
    required this.book,
    required this.local,
    required this.extractedAsync,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onExtract,
    required this.onOpenSection,
    required this.onOpenPage,
  });

  final OfficialBook book;
  final BookLocalState local;
  final AsyncValue<ExtractedBook?> extractedAsync;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onExtract;
  final ValueChanged<ExtractedSection> onOpenSection;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: TrText(
                    'الدروس والمذاكرة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: _ExtractionBadge(status: local.extractionStatus)),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            if (local.extractionStatus == BookExtractionStatus.extracting ||
                local.extractionStatus == BookExtractionStatus.organizing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ZakerSpacing.md),
                child: LinearProgressIndicator(minHeight: 7),
              )
            else if (!local.hasExtraction)
              _ExtractPrompt(
                canExtract:
                    local.downloadStatus == BookDownloadStatus.downloaded,
                status: local.extractionStatus,
                onExtract: onExtract,
              )
            else
              extractedAsync.when(
                loading: () => const LoadingBox(label: 'بنفتح الدروس المستخرجة…'),
                error: (error, _) => _ExtractError(
                  message: 'مقدرناش نقرا ملف الدروس: $error',
                ),
                data: (extracted) => extracted == null
                    ? _ExtractError(
                        message:
                            'ملف الدروس مش موجود. استخرج الكتاب تاني من '
                            'النسخة المنزّلة.',
                      )
                    : _SectionsBody(
                        book: book,
                        extracted: extracted,
                        searchController: searchController,
                        query: query,
                        onQueryChanged: onQueryChanged,
                        onOpenSection: onOpenSection,
                        onOpenPage: onOpenPage,
                        onReExtract: () => onExtract(false),
                      ),
              ),
            if (local.warnings.isNotEmpty) ...[
              const SizedBox(height: ZakerSpacing.sm),
              for (final warning in local.warnings.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TrText(
                    '• $warning',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExtractPrompt extends ConsumerWidget {
  const _ExtractPrompt({
    required this.canExtract,
    required this.status,
    required this.onExtract,
  });

  final bool canExtract;
  final BookExtractionStatus status;
  final ValueChanged<bool> onExtract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ocr = ref.watch(officialOcrEnabledProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          status == BookExtractionStatus.failed
              ? 'الاستخراج فشل قبل كده. تقدر تجرّب تاني من غير ما تنزّل الكتاب.'
              : 'لسه مااستخرجش نص الكتاب. الاستخراج بيحوّل الصفحات لدروس '
                    'وملخصات وكروت مربوطة برقم الصفحة.',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: ocr,
          onChanged: (value) =>
              ref.read(officialOcrEnabledProvider.notifier).state = value,
          title: const TrText('استخدم OCR للصفحات المصوّرة'),
          subtitle: const TrText(
            'بيشتغل للكتب العربية والإنجليزية بس، وممكن ياخد وقت.',
            style: TextStyle(fontSize: 10.5),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: canExtract ? () => onExtract(ocr) : null,
            icon: const Icon(Icons.text_snippet_outlined, size: 18),
            label: const TrText('استخرج الدروس'),
          ),
        ),
        if (!canExtract)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TrText(
              'لازم التنزيل يخلص ويتحقق منه الأول.',
              style: theme.textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _SectionsBody extends StatelessWidget {
  const _SectionsBody({
    required this.book,
    required this.extracted,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onOpenSection,
    required this.onOpenPage,
    required this.onReExtract,
  });

  final OfficialBook book;
  final ExtractedBook extracted;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ExtractedSection> onOpenSection;
  final ValueChanged<int> onOpenPage;
  final VoidCallback onReExtract;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hits = query.trim().isEmpty ? const <SearchHit>[] : extracted.search(query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: ZakerSpacing.sm,
          runSpacing: ZakerSpacing.sm,
          children: [
            _StatPill(
              label: '${extracted.sections.length} قسم',
              icon: Icons.segment_rounded,
            ),
            _StatPill(
              label: '${extracted.pageCount} صفحة',
              icon: Icons.description_outlined,
            ),
            _StatPill(
              label: '${extracted.textPageCount} نص',
              icon: Icons.text_fields_rounded,
            ),
            if (extracted.ocrPageCount > 0)
              _StatPill(
                label: '${extracted.ocrPageCount} OCR',
                icon: Icons.image_search_rounded,
              ),
          ],
        ),
        if (extracted.status == BookExtractionStatus.needsReview)
          Padding(
            padding: const EdgeInsets.only(top: ZakerSpacing.sm),
            child: TrText(
              'العناوين المستخرجة محتاجة مراجعة. الأقسام اللي مكتوب عليها '
              '«نطاق صفحات» مش عناوين رسمية، هي تقسيم مؤقت من غير تخمين.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: ZakerColors.accent,
                height: 1.5,
              ),
            ),
          ),
        const SizedBox(height: ZakerSpacing.md),
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'ابحث جوه نص الكتاب…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'امسح البحث',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (query.trim().isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.sm),
          if (hits.isEmpty)
            TrText(
              'مفيش نتايج لـ«$query» في نص الكتاب.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final hit in hits.take(12))
              _SearchHitTile(
                hit: hit,
                onTap: () {
                  onOpenPage(hit.pageNumber);
                },
              ),
        ],
        const SizedBox(height: ZakerSpacing.sm),
        if (extracted.sections.isEmpty)
          const EmptyState(
            icon: Icons.find_in_page_outlined,
            title: 'مفيش أقسام',
            message: 'النص المستخرج مفيهوش عناوين ولا تقسيم واضح.',
          )
        else
          for (final section in extracted.sections)
            _SectionTile(
              section: section,
              onTap: () => onOpenSection(section),
            ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onReExtract,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const TrText('إعادة الاستخراج'),
          ),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.onTap});

  final ExtractedSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        section.isFallback
            ? Icons.view_agenda_outlined
            : Icons.article_outlined,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      title: TrText(
        section.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          TrText(
            section.startPage == section.endPage
                ? 'صفحة ${section.startPage}'
                : 'صفحات ${section.startPage}–${section.endPage}',
            style: theme.textTheme.labelSmall,
          ),
          if (section.isFallback)
            TrText(
              '· نطاق صفحات',
              style: theme.textTheme.labelSmall?.copyWith(
                color: ZakerColors.accent,
              ),
            ),
          if (section.fromOcr)
            TrText(
              '· OCR',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_left_rounded, size: 18),
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZakerRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${hit.pageNumber}',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TrText(
                hit.snippet,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          TrText(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ExtractionBadge extends StatelessWidget {
  const _ExtractionBadge({required this.status});

  final BookExtractionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = switch (status) {
      BookExtractionStatus.ready => ZakerColors.success,
      BookExtractionStatus.needsReview => ZakerColors.accent,
      BookExtractionStatus.failed => ZakerColors.danger,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final color = readableTextColor(base, theme.colorScheme.surface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: TrText(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _ExtractError extends StatelessWidget {
  const _ExtractError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.md),
      child: TrText(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ZakerColors.danger,
          height: 1.5,
        ),
      ),
    );
  }
}

class _LockedTools extends StatelessWidget {
  const _LockedTools({required this.book});

  final OfficialBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TrText(
                book.hasDownload
                    ? 'نزّل الكتاب الرسمي الأول، وبعدها هيتحوّل لدروس '
                          'وشرح وملخصات وكروت مربوطة بالصفحات.'
                    : 'الكتاب لسه مش منشور رسميًا، فمفيش ملف نستخرج منه. '
                          'لما ينزل هيتضاف للفهرس بعد مراجعة المصدر.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageDetails extends StatelessWidget {
  const _StorageDetails({required this.local});

  final BookLocalState local;

  @override
  Widget build(BuildContext context) {
    if (!local.hasFile) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(
        Icons.storage_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: const TrText('الملفات المحلية'),
      subtitle: const TrText(
        'معاينة ونسخ احتياطية من غير ما نمسح النسخة المتحقق منها.',
        style: TextStyle(fontSize: 10.5),
      ),
      childrenPadding: const EdgeInsets.only(bottom: ZakerSpacing.md),
      children: [
        _DetailRow(label: 'ملف PDF', value: local.filePath),
        if (local.extractedPath.isNotEmpty)
          _DetailRow(label: 'ملف الدروس', value: local.extractedPath),
        if (local.sha256.isNotEmpty)
          _DetailRow(label: 'SHA-256', value: local.sha256),
        if (local.lastCheckedAt != null)
          _DetailRow(
            label: 'آخر فحص',
            value: _date(local.lastCheckedAt!),
          ),
        if (local.duplicateOf.isNotEmpty)
          _DetailRow(label: 'مشترك مع', value: local.duplicateOf),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: TrText(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.labelSmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatefulWidget {
  const _InlineNotice({
    required this.text,
    this.isError = false,
    this.onClose,
  });

  final String text;
  final bool isError;
  final VoidCallback? onClose;

  @override
  State<_InlineNotice> createState() => _InlineNoticeState();
}

class _InlineNoticeState extends State<_InlineNotice> {
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();
    final color = widget.isError
        ? ZakerColors.danger
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              widget.isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TrText(
                widget.text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'إغلاق',
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  setState(() => _closed = true);
                  widget.onClose?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _size(int bytes) {
  if (bytes <= 0) return 'حجم غير معروف';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} ك.ب';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
