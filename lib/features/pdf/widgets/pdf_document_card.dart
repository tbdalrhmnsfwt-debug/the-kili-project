/// A single document in «ملفاتي», plus the actions every surface shares.
///
/// Both the library screen and the hub's recent row use [PdfDocumentCard];
/// the dialogs and sheets live here so the two surfaces cannot drift apart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../models/pdf_document.dart';
import '../../../providers/pdf_providers.dart';
import '../../../widgets/tr_text.dart';
import 'pdf_thumbnail.dart';

/// How a card arranges its parts.
enum PdfDocumentCardLayout { grid, list }

enum _CardAction { rename, delete, share, details }

/// Human-readable file size.
String formatPdfSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} ك.ب';
  return '$bytes بايت';
}

/// Short date for the catalog.
String formatPdfDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}/${local.month}/${local.day}';
}

/// Opens the reader for [entry].
Future<void> openPdfDocument(BuildContext context, PdfDocumentEntry entry) {
  return context.push(
    '/pdf-viewer?docId=${Uri.encodeQueryComponent(entry.id)}',
  );
}

/// Asks for a new catalog name; an empty name changes nothing.
Future<void> renamePdfDocument(
  BuildContext context,
  WidgetRef ref,
  PdfDocumentEntry entry,
) async {
  final controller = ref.read(pdfLibraryControllerProvider.notifier);
  final field = TextEditingController(text: entry.displayName);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const TrText('إعادة تسمية'),
      content: TextField(
        controller: field,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'اسم الملف'),
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isEmpty) return;
          Navigator.of(context).pop(trimmed);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            final trimmed = field.text.trim();
            if (trimmed.isEmpty) return;
            Navigator.of(context).pop(trimmed);
          },
          child: const TrText('حفظ'),
        ),
      ],
    ),
  );
  field.dispose();
  if (name == null) return;
  await controller.rename(entry.id, name);
}

/// Confirms, then deletes the app's copy (never the user's original).
Future<void> deletePdfDocument(
  BuildContext context,
  WidgetRef ref,
  PdfDocumentEntry entry,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const TrText('حذف الملف'),
      content: TrText(
        'هيتشال «${entry.displayName}» من المكتبة. '
        'النسخة اللي جوّه التطبيق بس هي اللي بتتحذف، '
        'والملف الأصلي اللي اخترته مش هيتأثر.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const TrText('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const TrText('حذف'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(pdfLibraryControllerProvider.notifier).remove(entry.id);
}

/// Shares the app's copy after an explicit tap. Nothing is uploaded.
Future<void> sharePdfDocument(
  BuildContext context,
  WidgetRef ref,
  PdfDocumentEntry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final file = ref.read(pdfLibraryStoreProvider).baseFile(entry.id);
  if (!file.existsSync()) {
    messenger.showSnackBar(
      const SnackBar(content: TrText('الملف مش موجود في المكتبة.')),
    );
    return;
  }
  await Share.shareXFiles([XFile(file.path)], subject: entry.displayName);
}

/// The file they picked is never uploaded, logged or modified.
Future<void> showPdfDocumentDetails(
  BuildContext context,
  WidgetRef ref,
  PdfDocumentEntry entry,
) {
  final theme = Theme.of(context);
  final pages = entry.pageCount?.toString() ?? 'مش معروف';
  final opened = entry.lastOpenedAt == null
      ? 'لسه ما اتفتحش'
      : formatPdfDate(entry.lastOpenedAt!);
  final protection = switch (entry.encryption) {
    PdfEncryptionState.yes => 'محمي بكلمة سر',
    PdfEncryptionState.no => 'مش محمي',
    PdfEncryptionState.unknown => 'مش معروف',
  };
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          0,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrText(
              entry.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZakerSpacing.md),
            _DetailRow(label: 'الصفحات', value: pages),
            _DetailRow(label: 'الحجم', value: formatPdfSize(entry.sizeBytes)),
            _DetailRow(label: 'اتضاف', value: formatPdfDate(entry.addedAt)),
            _DetailRow(label: 'آخر فتح', value: opened),
            _DetailRow(label: 'الحماية', value: protection),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              'النسخة دي جوّه التطبيق. الملف الأصلي اللي اخترته مش بيتعدل، '
              'ومش بيتبعت لأي مكان غير لما تختار مشاركة بنفسك.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TrText('تم'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          TrText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TrText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// One catalog card.
class PdfDocumentCard extends StatelessWidget {
  const PdfDocumentCard({
    super.key,
    required this.entry,
    required this.layout,
    required this.available,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.onDetails,
  });

  final PdfDocumentEntry entry;
  final PdfDocumentCardLayout layout;

  /// Whether the app's copy still exists on disk.
  final bool available;

  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: available ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: available ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            child: layout == PdfDocumentCardLayout.grid
                ? _gridContent(context)
                : _listContent(context),
          ),
        ),
      ),
    );
  }

  Widget _gridContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PdfThumbnail(entry: entry),
            const Spacer(),
            _menu(theme),
          ],
        ),
        const SizedBox(height: ZakerSpacing.sm),
        _nameAndMeta(theme),
      ],
    );
  }

  Widget _listContent(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PdfThumbnail(entry: entry),
        const SizedBox(width: ZakerSpacing.md),
        Expanded(child: _nameAndMeta(theme)),
        _menu(theme),
      ],
    );
  }

  Widget _nameAndMeta(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TrText(
                entry.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (entry.favorite) ...[
              const SizedBox(width: ZakerSpacing.xs),
              Icon(Icons.star_rounded, size: 16, color: ZakerColors.accent),
            ],
          ],
        ),
        const SizedBox(height: 2),
        TrText(
          '${formatPdfSize(entry.sizeBytes)} • ${formatPdfDate(entry.addedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!available)
          TrText(
            'الملف مش موجود',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: ZakerColors.danger,
            ),
          ),
      ],
    );
  }

  Widget _menu(ThemeData theme) {
    return PopupMenuButton<_CardAction>(
      tooltip: 'خيارات',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case _CardAction.rename:
            onRename();
          case _CardAction.delete:
            onDelete();
          case _CardAction.share:
            onShare();
          case _CardAction.details:
            onDetails();
        }
      },
      itemBuilder: (context) {
        if (!available) {
          return const [
            PopupMenuItem(
              value: _CardAction.delete,
              child: TrText('شيل من المكتبة'),
            ),
          ];
        }
        return const [
          PopupMenuItem(
            value: _CardAction.rename,
            child: TrText('إعادة تسمية'),
          ),
          PopupMenuItem(value: _CardAction.share, child: TrText('مشاركة')),
          PopupMenuItem(value: _CardAction.details, child: TrText('تفاصيل')),
          PopupMenuItem(value: _CardAction.delete, child: TrText('حذف')),
        ];
      },
    );
  }
}
