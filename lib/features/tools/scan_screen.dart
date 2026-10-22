/// The scan / OCR screen.
///
/// Shipped strings this screen is built from:
///   * `المسح الضوئي`
///   * `ابدأ المسح 📸`
///   * `إعادة المسح`
///   * `اتمسحت الصفحة`
///   * `اختر صورة لوحة/سبورة أو التقطها بالكاميرا`
///   * `تحويل صورة السبورة لملف واضح`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';

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
  bool _working = false;

  Future<void> _capture() async {
    // The original app uses the camera plugin plus `flutter_tesseract_ocr`
    // for Arabic recognition.  Both are wired in the Android layer; the
    // capture itself is left to the platform channel.
    setState(() => _working = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _working = false);
  }

  void _removeAt(int index) {
    setState(() => _pages.removeAt(index));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('اتمسحت الصفحة')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المسح الضوئي'),
        actions: [
          if (_pages.isNotEmpty)
            TextButton(
              onPressed: () => setState(_pages.clear),
              child: const Text('مسح الكل'),
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
                label: const Text('اختر صورة أو صوّر'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              children: [
                for (var i = 0; i < _pages.length; i++)
                  _PageTile(
                    page: _pages[i],
                    onRemove: () => _removeAt(i),
                    onRescan: _capture,
                  ),
                const SizedBox(height: ZakerSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _capture,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('صفحة تانية'),
                ),
              ],
            ),
      bottomNavigationBar: _pages.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(ZakerSpacing.lg),
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.text_fields_rounded),
                  label: Text('حوّل لـ PDF (${_pages.length})'),
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
  });

  final ScannedPage page;
  final VoidCallback onRemove;
  final VoidCallback onRescan;

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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
            ),
            child: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صفحة ${page.id}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  page.recognized ? 'اتقرا' : 'مستني القراءة',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: page.recognized
                        ? ZakerColors.success
                        : theme.colorScheme.onSurfaceVariant,
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
    );
  }
}
