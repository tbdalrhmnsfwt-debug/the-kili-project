/// The small page preview used by library cards.
///
/// Thumbnails are optional: a document that has none (an encrypted import, or
/// a failed render) falls back to a neutral PDF glyph instead of a broken
/// image box.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/pdf_document.dart';
import '../../../providers/pdf_providers.dart';

/// Renders [entry]'s thumbnail, or a glyph when it has none.
class PdfThumbnail extends ConsumerWidget {
  const PdfThumbnail({
    super.key,
    required this.entry,
    this.width = 48,
    this.height = 64,
  });

  final PdfDocumentEntry entry;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final file = ref.watch(pdfLibraryStoreProvider).thumbFile(entry.id);
    final hasThumb =
        entry.thumbnailFileName != null &&
        file.existsSync() &&
        file.lengthSync() > 0;

    if (!hasThumb) {
      return _Glyph(
        width: width,
        height: height,
        color: entry.encryption == PdfEncryptionState.yes
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.primary,
        icon: entry.encryption == PdfEncryptionState.yes
            ? Icons.lock_outline_rounded
            : Icons.picture_as_pdf_outlined,
      );
    }

    return ClipRRect(
      borderRadius: ZakerRadius.card,
      child: Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _Glyph(
          width: width,
          height: height,
          color: theme.colorScheme.primary,
          icon: Icons.picture_as_pdf_outlined,
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.width,
    required this.height,
    required this.color,
    required this.icon,
  });

  final double width;
  final double height;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: ZakerRadius.card,
      ),
      child: Icon(icon, color: color, size: width * 0.55),
    );
  }
}
