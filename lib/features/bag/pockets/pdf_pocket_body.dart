/// The PDFs pocket of one bag folder: the files the user attached here.
///
/// The pocket only stores references to «ملفاتي» documents; the files
/// themselves live in the library. A reference whose document is gone is
/// dropped when the pocket opens, and one whose file vanished is shown as
/// stale with a way to forget it — never as a crash.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../models/pdf_document.dart';
import '../../../providers/my_bag_providers.dart';
import '../../../providers/pdf_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../../pdf/widgets/pdf_document_card.dart';
import '../../pdf/widgets/pdf_import_button.dart';
import '../../pdf/widgets/pdf_thumbnail.dart';

class PdfPocketBody extends ConsumerStatefulWidget {
  const PdfPocketBody({super.key, required this.folderId});

  final String folderId;

  @override
  ConsumerState<PdfPocketBody> createState() => _PdfPocketBodyState();
}

class _PdfPocketBodyState extends ConsumerState<PdfPocketBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prune());
  }

  /// Drops references the library no longer knows. Runs after the first
  /// frame so the controller is not mutated during a build.
  void _prune() {
    if (!mounted) return;
    final folder =
        ref.read(myBagControllerProvider).folderById(widget.folderId);
    if (folder == null || folder.pdfIds.isEmpty) return;
    final library = ref.read(pdfLibraryControllerProvider);
    final known = <String>{
      for (final id in folder.pdfIds)
        if (library.entryById(id) != null) id,
    };
    if (known.length == folder.pdfIds.length) return;
    unawaited(ref.read(myBagControllerProvider.notifier).prunePdfRefs(known));
  }

  Future<void> _import() async {
    final folder =
        ref.read(myBagControllerProvider).folderById(widget.folderId);
    if (folder == null) return;
    final imported = await importPdfFiles(context, ref);
    if (imported.isEmpty || !mounted) return;
    final library = ref.read(pdfLibraryControllerProvider.notifier);
    final bag = ref.read(myBagControllerProvider.notifier);
    final taggable = folder.gradeId.isNotEmpty || folder.subjectKey.isNotEmpty;
    for (final entry in imported) {
      if (taggable) {
        await library.setSubjectTag(
          entry.id,
          gradeId: folder.gradeId,
          subjectKey: folder.subjectKey,
        );
      }
      await bag.addPdfRef(widget.folderId, entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bag = ref.watch(myBagControllerProvider);
    final library = ref.watch(pdfLibraryControllerProvider);
    final store = ref.watch(pdfLibraryStoreProvider);
    final folder = bag.folderById(widget.folderId);
    final rows = <Widget>[
      for (final id in folder?.pdfIds ?? const <String>[])
        if (library.entryById(id) case final entry?)
          _entryTile(context, entry, store.baseFile(entry.id).existsSync()),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const TrText('ملفات PDF'),
            actions: [
              IconButton(
                key: const Key('bag-pocket-add'),
                tooltip: _t(context, 'أضف PDF'),
                onPressed: _import,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.picture_as_pdf_outlined,
                title: 'مفيش ملفات',
                message: 'ضيف ملزمة أو امتحان من ملفاتك.',
                action: FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.add),
                  label: const TrText('أضف PDF'),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => rows[index],
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(ZakerSpacing.md),
              child: Center(
                child: TextButton.icon(
                  key: const Key('bag-pdf-library'),
                  onPressed: () => context.push(ZakerRoutes.pdfLibrary),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const TrText('فتح ملفاتي'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(
    BuildContext context,
    PdfDocumentEntry entry,
    bool available,
  ) {
    if (!available) {
      return ListTile(
        key: Key('bag-pdf-stale-${entry.id}'),
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(
          entry.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: const TrText('الملف مش موجود'),
        trailing: TextButton(
          key: Key('bag-pdf-forget-${entry.id}'),
          onPressed: () => unawaited(
            ref
                .read(myBagControllerProvider.notifier)
                .removePdfRef(widget.folderId, entry.id),
          ),
          child: const TrText('أزل المرجع'),
        ),
      );
    }

    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      key: Key('bag-pdf-${entry.id}'),
      leading: PdfThumbnail(entry: entry, width: 44, height: 56),
      title: Text(
        entry.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPdfSize(entry.sizeBytes),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
          TrText(
            entry.pageCount == null
                ? 'صفحة ${entry.lastPage}'
                : 'صفحة ${entry.lastPage} من ${entry.pageCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ],
      ),
      trailing: entry.favorite
          ? Icon(Icons.star_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: () => openPdfDocument(context, entry),
      onLongPress: () => _showActions(context, entry),
    );
  }

  Future<void> _showActions(BuildContext context, PdfDocumentEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const TrText('افتح'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(openPdfDocument(context, entry));
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const TrText('شارك'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(sharePdfDocument(context, ref, entry));
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const TrText('أعد التسمية'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(renamePdfDocument(context, ref, entry));
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: const TrText('أزل من الشنطة'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(
                  ref
                      .read(myBagControllerProvider.notifier)
                      .removePdfRef(widget.folderId, entry.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Translates for places that need a plain [String], falling back to the
  /// Arabic source when no localisation delegate is installed (tests).
  static String _t(BuildContext context, String key) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)?.t(key) ??
      key;
}
