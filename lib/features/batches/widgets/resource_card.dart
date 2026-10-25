/// One resource inside a subject: thumbnail, facts, star and delete.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_resource_paths.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../models/batch_resource.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/tr_text.dart';
import '../../../widgets/zaker_visuals.dart';
import '../batch_error_text.dart';
import 'batch_labels.dart';

class ResourceCard extends ConsumerWidget {
  const ResourceCard({
    super.key,
    required this.batchId,
    required this.resource,
    required this.uid,
  });

  final String batchId;
  final BatchResource resource;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final path = BatchResourcePaths.filePath(resource);
    final missing = path != null &&
        (ref
                .watch(
                  resourceMissingProvider(
                    (batchId: batchId, relativePath: path),
                  ),
                )
                .valueOrNull ??
            false);
    final thumbnail = resource.kind == ResourceKind.pdf
        ? ref
            .watch(
              resourceThumbnailProvider(
                (batchId: batchId, resourceId: resource.id),
              ),
            )
            .valueOrNull
        : null;
    final starred = resource.starredBy.contains(uid);
    final absolutePath = path == null
        ? null
        : ref
            .watch(batchFileStoreProvider)
            .fileInBatch(uid, batchId, path)
            .path;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: missing
              ? theme.colorScheme.error.withValues(alpha: 0.35)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: missing ? null : () => _open(context, theme, absolutePath),
            child: Padding(
              padding: const EdgeInsets.all(ZakerSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Leading(thumbnail: thumbnail, kind: resource.kind),
                  const SizedBox(width: ZakerSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          resource.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TrText(
                          _metaLine(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (resource.kind == ResourceKind.audio) ...[
                          const SizedBox(height: ZakerSpacing.xs),
                          const _TranscriptionBadge(),
                        ],
                        if (missing) ...[
                          const SizedBox(height: ZakerSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.link_off_rounded,
                                size: 14,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TrText(
                                  'الملف مش موجود على الجهاز.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: starred ? 'إزالة التمييز' : 'تمييز',
                    onPressed: () => _toggleStar(context, ref, !starred),
                    icon: Icon(
                      starred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: starred
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات الملف',
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete(context, ref);
                    },
                    itemBuilder: (menuContext) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: TrText('حذف الملف'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine() {
    final parts = <String>[
      if (resource.uploaderUid == uid) 'أنت' else 'عضو',
      formatBatchDate(resource.createdAt),
      if (resource.kind == ResourceKind.note)
        'ملاحظة نصية'
      else if (resource.kind == ResourceKind.pdf)
        formatBytes(resource.sizeBytes)
      else
        resource.durationMs == null
            ? formatBytes(resource.sizeBytes)
            : formatDuration(resource.durationMs!),
    ];
    return parts.join(' · ');
  }

  void _open(BuildContext context, ThemeData theme, String? absolutePath) {
    switch (resource.kind) {
      case ResourceKind.pdf:
        if (absolutePath == null) return;
        // The viewer receives the absolute private path, never a public URL.
        context.push(
          '${ZakerRoutes.pdfViewer}?path=${Uri.encodeQueryComponent(absolutePath)}'
          '&title=${Uri.encodeQueryComponent(resource.title)}',
        );
      case ResourceKind.note:
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: TrText(resource.title),
            content: SingleChildScrollView(
              child: SelectableText(
                resource.note,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const TrText('تمام'),
              ),
            ],
          ),
        );
      case ResourceKind.audio:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TrText('المشغّل الصوتي مش متاح في النسخة دي.'),
          ),
        );
    }
  }

  Future<void> _toggleStar(
    BuildContext context,
    WidgetRef ref,
    bool starred,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(batchControllerProvider)
          .setStarred(batchId, resource.id, starred);
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف الملف؟'),
        content: TrText(
          'هيتم مسح «${resource.title}» والنسخة المحفوظة على الجهاز. '
          'مفيش نسخة على سيرفر ترجعها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(batchControllerProvider).deleteResource(
            batchId,
            resource.id,
          );
      messenger.showSnackBar(
        const SnackBar(content: TrText('اتمسح الملف من الجهاز.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.thumbnail, required this.kind});

  final Uint8List? thumbnail;
  final ResourceKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        child: Image.memory(
          thumbnail!,
          width: 42,
          height: 52,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return ZakerGlassGlyph(
      icon: switch (kind) {
        ResourceKind.pdf => Icons.picture_as_pdf_outlined,
        ResourceKind.audio => Icons.graphic_eq_rounded,
        ResourceKind.note => Icons.sticky_note_2_outlined,
      },
      accent: theme.colorScheme.primary,
      size: 42,
      iconSize: 22,
      radius: ZakerRadius.sm,
    );
  }
}

class _TranscriptionBadge extends StatelessWidget {
  const _TranscriptionBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.subtitles_off_outlined,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: TrText(
              'التفريغ: غير متاح محليًا',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
