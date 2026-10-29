/// The scan / OCR screen.
///
/// Shipped strings this screen is built from:
///   * `المسح الضوئي`
///   * `ابدأ المسح 📸`
///   * `إعادة المسح`
///   * `اتمسحت الصفحة`
///   * `اختر صورة لوحة/سبورة أو التقطها بالكاميرا`
///   * `تحويل صورة السبورة لملف واضح`
///
/// Capturing goes through `image_picker`, recognition through
/// `flutter_tesseract_ocr` using the bundled Arabic/English trained data, and
/// the finished pages are shared as a PDF.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../core/my_bag/image_pdf_builder.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// A captured page waiting to be recognised.
class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.imagePath,
    this.text = '',
    this.recognized = false,
  });

  final String id;
  final String imagePath;

  /// The OCR output.
  final String text;

  final bool recognized;

  ScannedPage copyWith({String? text, bool? recognized}) => ScannedPage(
        id: id,
        imagePath: imagePath,
        text: text ?? this.text,
        recognized: recognized ?? this.recognized,
      );
}

/// The scan / OCR screen.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final List<ScannedPage> _pages = [];
  final ImagePicker _picker = ImagePicker();
  bool _working = false;

  /// Asks for a source, captures a page and runs OCR on it.
  Future<void> _capture() async {
    if (_working) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const TrText('صوّر الصفحة'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const TrText('اختار من المعرض'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: ZakerSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
    } catch (e) {
      _snack('مقدرناش نفتح الكاميرا أو المعرض.');
      return;
    }
    if (shot == null || !mounted) return;

    final page = ScannedPage(id: '${_pages.length + 1}', imagePath: shot.path);
    setState(() => _pages.add(page));
    await _recognize(page);
  }

  /// Runs Tesseract over [page] and fills in its text.
  Future<void> _recognize(ScannedPage page) async {
    setState(() => _working = true);
    try {
      final text = await FlutterTesseractOcr.extractText(
        page.imagePath,
        language: 'ara+eng',
        args: const {
          'psm': '4',
          'preserve_interword_spaces': '1',
        },
      );
      if (!mounted) return;
      setState(() {
        final index = _pages.indexWhere((p) => p.id == page.id);
        if (index >= 0) {
          _pages[index] = _pages[index].copyWith(
            text: text.trim(),
            recognized: true,
          );
        }
      });
      _snack('اتقرات الصفحة.');
    } catch (e) {
      _snack('مقدرناش نقرا الصفحة — الصورة محفوظة، تقدر تعيد المسح.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Builds a PDF of the captured pages and opens the share sheet.
  Future<void> _exportPdf() async {
    if (_pages.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      final bytes = await buildImagePdf([
        for (final page in _pages) page.imagePath,
      ]);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'zaker-scan-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      _snack('مقدرناش نعمل PDF: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _removeAt(int index) {
    setState(() => _pages.removeAt(index));
    _snack('اتمسحت الصفحة');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }

  /// Shows the recognised text so it can be read or copied.
  Future<void> _showText(ScannedPage page) async {
    final text =
        page.text.isEmpty ? 'لسه مفيش نص مقروء من الصفحة دي.' : page.text;
    await showModalBottomSheet<void>(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'نص الصفحة ${page.id}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child:
                      SelectableText(text, style: const TextStyle(height: 1.7)),
                ),
              ),
              if (page.text.isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: page.text));
                      if (context.mounted) Navigator.of(context).pop();
                      _snack('اتنسخ النص.');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const TrText('انسخ النص'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TrText('المسح الضوئي'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton(
              onPressed: () => setState(_pages.clear),
              child: const TrText('مسح الكل'),
            ),
        ],
      ),
      body: _pages.isEmpty
          ? EmptyState(
              icon: Icons.document_scanner_rounded,
              title: 'ابدأ المسح 📸',
              message:
                  'صوّر الصفحة أو اختر صورة سبورة، والتطبيق يقراها بالذكاء.',
              action: FilledButton.icon(
                onPressed: _working ? null : _capture,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const TrText('اختر صورة أو صوّر'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              children: [
                if (_working)
                  const Padding(
                    padding: EdgeInsets.only(bottom: ZakerSpacing.md),
                    child: LinearProgressIndicator(),
                  ),
                for (var i = 0; i < _pages.length; i++)
                  _PageTile(
                    page: _pages[i],
                    onRemove: () => _removeAt(i),
                    onRescan: () => _recognize(_pages[i]),
                    onOpen: () => _showText(_pages[i]),
                  ),
                const SizedBox(height: ZakerSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _working ? null : _capture,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const TrText('صفحة تانية'),
                ),
              ],
            ),
      bottomNavigationBar: _pages.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(ZakerSpacing.lg),
                child: FilledButton.icon(
                  onPressed: _working ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: TrText('حوّل لـ PDF (${_pages.length})'),
                ),
              ),
            ),
    );
  }
}

/// A single scanned page.
class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.onRemove,
    required this.onRescan,
    required this.onOpen,
  });

  final ScannedPage page;
  final VoidCallback onRemove;
  final VoidCallback onRescan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
              child: SizedBox(
                width: 48,
                height: 60,
                child: Image.file(
                  File(page.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    child: Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText(
                    'صفحة ${page.id}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TrText(
                    page.recognized ? 'اتقرا' : 'مستني القراءة',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: page.recognized
                          ? ZakerColors.success
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (page.text.isNotEmpty)
                    TrText(
                      page.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'إعادة المسح',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRescan,
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
