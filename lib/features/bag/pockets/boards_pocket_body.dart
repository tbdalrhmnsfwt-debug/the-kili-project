/// The boards pocket of one bag folder: photos of a board or a notebook.
///
/// Tiles keep their order, and «كوّن PDF» turns that order into one PDF in
/// «ملفاتي» tagged with the folder's subject — the images stay in the bag.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/localization.dart';
import '../../../core/my_bag/image_pdf_builder.dart';
import '../../../core/my_bag/my_bag_controller.dart';
import '../../../core/my_bag/my_bag_models.dart';
import '../../../core/pdf/pdf_library_controller.dart';
import '../../../core/theme.dart';
import '../../../models/pdf_document.dart';
import '../../../providers/my_bag_providers.dart';
import '../../../providers/pdf_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../../pdf/widgets/pdf_document_card.dart';
import '../bag_image_picker.dart';

/// The most images one pick may add at once.
const int kMaxBoardsPerPick = 25;

class BoardsPocketBody extends ConsumerStatefulWidget {
  const BoardsPocketBody({super.key, required this.folderId});

  final String folderId;

  @override
  ConsumerState<BoardsPocketBody> createState() => _BoardsPocketBodyState();
}

class _BoardsPocketBodyState extends ConsumerState<BoardsPocketBody> {
  bool _compiling = false;

  String get _folderId => widget.folderId;

  @override
  Widget build(BuildContext context) {
    final bag = ref.watch(myBagControllerProvider);
    final boards = bag.mediaOf(_folderId).boards;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 700 ? 3 : 2;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const TrText('صور بورد'),
            actions: [
              IconButton(
                key: const Key('bag-board-add'),
                tooltip: context.tr('أضف صور'),
                onPressed: _add,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ],
          ),
          if (boards.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.image_outlined,
                title: 'مفيش صور',
                message: 'صوّر البورد أو اختار صور من المعرض.',
                action: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const TrText('أضف صور'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: ZakerSpacing.sm,
                  crossAxisSpacing: ZakerSpacing.sm,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _tile(boards[index], index, boards),
                  childCount: boards.length,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          child: FilledButton.icon(
            key: const Key('bag-boards-compile'),
            onPressed: boards.isEmpty || _compiling ? null : _compile,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: TrText(_compiling ? 'بنكوّن ملف PDF…' : 'كوّن PDF'),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    MyBagBoardImage image,
    int index,
    List<MyBagBoardImage> boards,
  ) {
    final theme = Theme.of(context);
    final file =
        ref.read(myBagStoreProvider).boardFile(_folderId, image.fileName);
    final preview = _preview(file, theme);
    return DragTarget<String>(
      key: Key('bag-board-${image.id}'),
      onWillAcceptWithDetails: (details) => details.data != image.id,
      onAcceptWithDetails: (details) {
        final from = boards.indexWhere((board) => board.id == details.data);
        if (from < 0) return;
        unawaited(
          ref
              .read(myBagControllerProvider.notifier)
              .reorderBoardImages(_folderId, from, index),
        );
      },
      builder: (context, candidate, rejected) => LongPressDraggable<String>(
        data: image.id,
        feedback: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: ZakerRadius.card,
            child: SizedBox(width: 96, height: 96, child: preview),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: preview),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: ZakerRadius.card,
                child: preview,
              ),
            ),
            Positioned(
              top: ZakerSpacing.xs,
              left: ZakerSpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZakerSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(ZakerRadius.pill),
                ),
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: ZakerSpacing.xs,
              right: ZakerSpacing.xs,
              child: IconButton(
                key: Key('bag-board-delete-${image.id}'),
                tooltip: context.tr('احذف'),
                onPressed: () => _delete(image),
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(File file, ThemeData theme) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<BagImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('bag-board-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const TrText('كاميرا'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(BagImageSource.camera),
            ),
            ListTile(
              key: const Key('bag-board-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const TrText('المعرض'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(BagImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const TrText('إلغاء'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final List<BagPickedImage> picked;
    try {
      picked = await ref.read(bagImagePickerProvider).pick(source: source);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: TrText('مقدرناش نفتح الكاميرا أو المعرض.')),
      );
      return;
    }
    if (picked.isEmpty || !mounted) return;

    var images = picked;
    if (images.length > kMaxBoardsPerPick) {
      images = images.take(kMaxBoardsPerPick).toList();
      messenger.showSnackBar(
        const SnackBar(content: TrText('أقصى 25 صورة في المرة.')),
      );
    }
    final current =
        ref.read(myBagControllerProvider).mediaOf(_folderId).boards.length;
    if (current >= kMaxBoardImages) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('حد أقصى 200 صورة في المجلد.')),
      );
      return;
    }
    if (current + images.length > kMaxBoardImages) {
      images = images.take(kMaxBoardImages - current).toList();
      messenger.showSnackBar(
        const SnackBar(content: TrText('حد أقصى 200 صورة في المجلد.')),
      );
    }

    final controller = ref.read(myBagControllerProvider.notifier);
    for (final image in images) {
      try {
        await controller.addBoardImage(
          _folderId,
          bytes: image.bytes,
          width: image.width,
          height: image.height,
          extension: p.extension(image.path).toLowerCase(),
        );
      } on StateError {
        messenger.showSnackBar(
          const SnackBar(content: TrText('حد أقصى 200 صورة في المجلد.')),
        );
        return;
      }
    }
  }

  Future<void> _delete(MyBagBoardImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('حذف الصورة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZakerColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const TrText('احذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(myBagControllerProvider.notifier)
        .deleteBoardImage(_folderId, image.id);
  }

  Future<void> _compile() async {
    if (_compiling) return;
    final messenger = ScaffoldMessenger.of(context);
    final folder = ref.read(myBagControllerProvider).folderById(_folderId);
    final boards = ref.read(myBagControllerProvider).mediaOf(_folderId).boards;
    final pdfController = ref.read(pdfLibraryControllerProvider.notifier);
    if (folder == null || boards.isEmpty || pdfController.isBusy) return;
    // A compile is capped at 25 images so a 200-image folder cannot be turned
    // into one enormous in-memory PDF.
    if (boards.length > kMaxBoardsPerPick) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('أقصى 25 صورة في المرة.')),
      );
      return;
    }
    final store = ref.read(myBagStoreProvider);
    setState(() => _compiling = true);
    try {
      final bytes = await buildImagePdf([
        for (final board in boards)
          store.boardFile(_folderId, board.fileName).path,
      ]);
      final now = DateTime.now();
      final result = await pdfController.import([
        PdfImportSource(
          name: '${folder.name} - ${now.year}/${now.month}/${now.day}.pdf',
          sizeBytes: bytes.length,
          openRead: () => Stream.value(bytes),
        ),
      ]);
      final bag = ref.read(myBagControllerProvider.notifier);
      for (final entry in result.imported) {
        await pdfController.setSubjectTag(
          entry.id,
          gradeId: folder.gradeId,
          subjectKey: folder.subjectKey,
          sourceDocId: folder.id,
        );
        await bag.addPdfRef(_folderId, entry.id);
      }
      if (!mounted) return;
      if (result.imported.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: TrText('مقدرناش نكوّن ملف PDF.')),
        );
        return;
      }
      await _showCreated(result.imported.first);
    } on ArgumentError {
      messenger.showSnackBar(
        const SnackBar(content: TrText('مفيش صور تتكوّن في PDF.')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: TrText('مقدرناش نكوّن ملف PDF.')),
      );
    } finally {
      if (mounted) setState(() => _compiling = false);
    }
  }

  Future<void> _showCreated(PdfDocumentEntry entry) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('تم تكوين ملف PDF'),
        content: Text(entry.displayName),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(openPdfDocument(context, entry));
            },
            child: const TrText('افتح'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(sharePdfDocument(context, ref, entry));
            },
            child: const TrText('شارك'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const TrText('تم'),
          ),
        ],
      ),
    );
  }
}
