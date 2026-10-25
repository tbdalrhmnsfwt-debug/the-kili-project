/// Opens an official textbook in the in-app PDF reader.
///
/// A catalog row is only a verified URL; the PDF itself must be downloaded and
/// validated first. This helper keeps the tap promise direct: it opens an
/// already-cached file immediately, or shows one download sheet with live
/// progress and switches to the reader as soon as the verified file exists.
/// Nothing is invented for unpublished rows.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/book_download_service.dart';
import '../../core/theme.dart';
import '../../models/official_book.dart';
import '../../providers/official_library_providers.dart';
import '../../widgets/tr_text.dart';
import '../tools/pdf_viewer_screen.dart';

/// Opens [book] in the embedded reader, downloading it when necessary.
Future<void> openOfficialBook(
  BuildContext context,
  WidgetRef ref,
  OfficialBook book,
) async {
  final view = ref.read(officialLibraryControllerProvider).valueOrNull;
  final local = view?.stateOf(book) ?? book.initialState();

  if (local.filePath.isNotEmpty && await File(local.filePath).exists()) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _openReader(context, local.filePath, book);
    return;
  }

  if (!book.hasDownload) {
    if (!context.mounted) return;
    await _showUnavailable(context, book);
    return;
  }

  if (!context.mounted) return;
  final path = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DownloadSheet(book: book),
  );
  if (path == null || path.isEmpty || !context.mounted) return;
  _openReader(context, path, book);
}

void _openReader(BuildContext context, String path, OfficialBook book) {
  context.push(PdfViewerScreen.location(path, title: book.titleAr));
}

Future<void> _showUnavailable(BuildContext context, OfficialBook book) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const TrText('الكتاب مش متاح للتنزيل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(book.titleAr),
          const SizedBox(height: 8),
          TrText(
            '${book.status.label} · ${book.statusExplanation}',
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const TrText('تمام'),
        ),
      ],
    ),
  );
}

/// Live download progress for one official book, then the reader.
class _DownloadSheet extends ConsumerStatefulWidget {
  const _DownloadSheet({required this.book});

  final OfficialBook book;

  @override
  ConsumerState<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends ConsumerState<_DownloadSheet> {
  bool _requested = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  /// Starts the verified download once, or opens the file when it is ready.
  void _sync() {
    if (!mounted) return;
    final view = ref.read(officialLibraryControllerProvider).valueOrNull;
    if (view == null) return;
    final local = view.stateOf(widget.book);

    if (local.downloadStatus == BookDownloadStatus.downloaded &&
        local.filePath.isNotEmpty) {
      if (_opening) return;
      _opening = true;
      unawaited(_openWhenPresent(local.filePath));
      return;
    }
    if (_requested || local.downloadStatus.isBusy) return;
    _requested = true;
    unawaited(_request());
  }

  /// Checks the recorded path before handing it to the viewer.
  Future<void> _openWhenPresent(String path) async {
    final exists = await File(path).exists();
    if (!mounted) return;
    // The sheet may already be closing («لاحقًا» or a drag) when the download
    // finishes. Popping then would remove the screen underneath it instead.
    if (ModalRoute.of(context)?.isCurrent != true) {
      _opening = false;
      return;
    }
    if (exists) {
      Navigator.of(context).pop(path);
      return;
    }
    // The library state survived but the file did not. Ask the verified
    // downloader to restore it instead of opening a missing path.
    _opening = false;
    _requested = true;
    await _request();
  }

  Future<void> _request() => ref
      .read(officialLibraryControllerProvider.notifier)
      .requestDownload(widget.book);

  void _retry() {
    _requested = true;
    _opening = false;
    unawaited(_request());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(officialLibraryControllerProvider);
    final view = async.valueOrNull;
    final local = view?.stateOf(widget.book) ?? widget.book.initialState();
    final progress = view?.progress[widget.book.id];
    final status = local.downloadStatus;

    if (view != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }

    final busy = status.isBusy;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TrText(
                      widget.book.titleAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TrText(
                async.hasError && view == null
                    ? 'تعذّر تجهيز مكتبة التنزيل على الجهاز.'
                    : _statusLine(status),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (async.hasError) ...[
                const SizedBox(height: 8),
                TrText(
                  'تعذّر تجهيز المكتبة: ${async.error}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (busy || status == BookDownloadStatus.downloaded) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: status == BookDownloadStatus.downloaded
                      ? 1
                      : progress?.fraction ?? local.progress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 7),
                TrText(
                  status == BookDownloadStatus.downloaded
                      ? 'الملف جاهز، بنفتح القارئ…'
                      : _progressLine(progress),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (local.error.isNotEmpty && !busy) ...[
                const SizedBox(height: 10),
                TrText(
                  local.error,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: ZakerSpacing.sm,
                runSpacing: ZakerSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (busy)
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(officialLibraryControllerProvider.notifier)
                          .cancelDownload(widget.book),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const TrText('إلغاء التنزيل'),
                    )
                  else if (status == BookDownloadStatus.failed ||
                      status == BookDownloadStatus.cancelled)
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const TrText('جرّب تاني'),
                    )
                  else if (async.hasError)
                    FilledButton.icon(
                      onPressed: () {
                        _requested = false;
                        _opening = false;
                        ref.invalidate(officialLibraryControllerProvider);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const TrText('أعد المحاولة'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const TrText('بنحضّر التنزيل…'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const TrText('لاحقًا'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.offline_pin_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TrText(
                      'الملف بيتحمّل من الرابط الرسمي ويتحفظ على الجهاز، '
                      'فيفتح بعد كده من غير إنترنت.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLine(BookDownloadStatus status) => switch (status) {
    BookDownloadStatus.queued => 'الكتاب في قائمة التنزيل…',
    BookDownloadStatus.downloading => 'بننزّل الكتاب الرسمي ونتحقق منه…',
    BookDownloadStatus.downloaded => 'الكتاب منزّل على الجهاز.',
    BookDownloadStatus.failed => 'التنزيل فشل. جرّب تاني.',
    BookDownloadStatus.cancelled => 'اتلغى التنزيل. تقدر تكمّل في أي وقت.',
    BookDownloadStatus.needsUpdate => 'فيه نسخة أحدث من الكتاب.',
    _ => 'بنجهز التنزيل…',
  };

  static String _progressLine(DownloadProgress? progress) {
    if (progress == null) return 'بنبدأ التنزيل…';
    final total = progress.total > 0
        ? formatOfficialFileSize(progress.total)
        : 'حجم غير معروف';
    return '${progress.percent}% · ${formatOfficialFileSize(progress.received)} من $total';
  }
}

String formatOfficialFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}
