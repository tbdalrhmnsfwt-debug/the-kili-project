/// The PDF viewer screen.
///
/// The replica ships no platform PDF-view plugin (no `flutter_pdfview` /
/// `pdfx` in the offline package cache), so the viewer is built on
/// `printing`'s [PdfPreview], which rasterises each page on device. That makes
/// the screen ready to display any PDF handed to it — a picked file, a path
/// pushed by another screen, or bytes held in memory — while staying fully
/// offline.
///
/// States covered: nothing open, loading, unreadable/corrupt file, and a
/// ready document with share / print / page controls.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// A full-screen PDF reader.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    this.path,
    this.title,
    this.bytes,
    this.fileName,
  });

  /// A local file path to open on first build.
  final String? path;

  /// The fallback title shown in the app bar.
  final String? title;

  /// Bytes to display directly (used when another screen already has them).
  final Uint8List? bytes;

  /// The document name used when sharing. Defaults to the picked file name.
  final String? fileName;

  /// The route location for [path], with the title carried as a query value.
  static String location(String path, {String? title}) {
    final query = <String>[
      'path=${Uri.encodeQueryComponent(path)}',
      if (title != null && title.isNotEmpty)
        'title=${Uri.encodeQueryComponent(title)}',
    ].join('&');
    return '${ZakerRoutes.pdfViewer}?$query';
  }

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  String? _name;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.bytes;
    if (initial != null && initial.isNotEmpty) {
      _bytes = initial;
      _name = widget.fileName ?? widget.title;
    } else if (widget.path != null && widget.path!.isNotEmpty) {
      _loadPath(widget.path!);
    }
  }

  /// Reads a PDF from disk and validates its magic bytes.
  Future<void> _loadPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      _accept(bytes, file.uri.pathSegments.last);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Opens the system picker and loads the chosen PDF.
  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final file = result.files.single;
      var bytes = file.bytes;
      final path = file.path;
      if ((bytes == null || bytes.isEmpty) && path != null) {
        bytes = await File(path).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('الملف فاضي أو مش مقروء.');
      }
      _accept(bytes, file.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Validates and stores [bytes] as the open document.
  void _accept(Uint8List bytes, String name) {
    final looksLikePdf =
        bytes.length >= 5 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
    if (!looksLikePdf) {
      throw const FormatException('الملف ده مش PDF صالح.');
    }
    if (!mounted) return;
    if (_isEncrypted(bytes)) {
      setState(() => _loading = false);
      _unlockAndOpen(bytes, name);
      return;
    }
    setState(() {
      _bytes = bytes;
      _name = name;
      _error = null;
      _loading = false;
    });
  }

  /// True when the PDF carries an `/Encrypt` dictionary.
  static bool _isEncrypted(Uint8List bytes) {
    const marker = [0x2F, 0x45, 0x6E, 0x63, 0x72, 0x79, 0x70, 0x74];
    final limit = bytes.length - marker.length;
    for (var i = 0; i <= limit; i++) {
      var match = true;
      for (var j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  /// Opens an encrypted PDF: first with an empty password (permissions-only
  /// encryption), then by asking the student for the file password.
  Future<void> _unlockAndOpen(Uint8List bytes, String name) async {
    final free = await _decrypt(bytes, '');
    if (!mounted) return;
    if (free != null) {
      _showOpened(free, name, unlocked: true);
      return;
    }

    for (var attempt = 0; attempt < 3 && mounted; attempt++) {
      final password = await _askPassword(firstAttempt: attempt == 0);
      if (!mounted || password == null) return;
      final unlocked = await _decrypt(bytes, password);
      if (!mounted) return;
      if (unlocked != null) {
        _showOpened(unlocked, name, unlocked: true);
        return;
      }
      if (attempt < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('كلمة السر مش صح — جرّب تاني.')),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _error = 'الملف مشفر ومقدرناش نفتحه. اتأكد من كلمة السر أو اطلب نسخة '
          'مش محمية من صاحب الملف.';
      _loading = false;
    });
  }

  void _showOpened(Uint8List bytes, String name, {bool unlocked = false}) {
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _name = name;
      _error = null;
      _loading = false;
    });
    if (unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('اتفك تشفير الملف واتفتح ✅')),
      );
    }
  }

  /// Returns decrypted bytes, or null when [password] does not unlock the file.
  Future<Uint8List?> _decrypt(Uint8List bytes, String password) async {
    sf.PdfDocument? document;
    try {
      document = sf.PdfDocument(inputBytes: bytes, password: password);
      final saved = document.saveSync();
      return Uint8List.fromList(saved);
    } catch (_) {
      return null;
    } finally {
      document?.dispose();
    }
  }

  Future<String?> _askPassword({required bool firstAttempt}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('الملف محمي بكلمة سر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              firstAttempt
                  ? 'اكتب كلمة سر الملف عشان نقدر نعرضه على الجهاز.'
                  : 'جرّب كلمة سر تانية.',
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.of(context).pop(value),
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const TrText('فتح'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      await Printing.sharePdf(bytes: bytes, filename: _shareName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TrText('مقدرناش نشارك الملف: $e')),
      );
    }
  }

  void _close() {
    setState(() {
      _bytes = null;
      _name = null;
      _error = null;
    });
  }

  /// Makes sure the shared file name ends in `.pdf`.
  String get _shareName {
    final raw = _name ?? widget.fileName ?? 'zaker-document.pdf';
    final base = raw.trim().isEmpty ? 'zaker-document' : raw.trim();
    return base.toLowerCase().endsWith('.pdf') ? base : '$base.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = _bytes != null;
    return Scaffold(
      appBar: AppBar(
        title: TrText(
          _name ??
              widget.fileName ??
              widget.title ??
              (hasDocument ? 'قارئ PDF' : 'افتح PDF'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'افتح ملف',
            onPressed: _loading ? null : _pick,
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton(
            tooltip: 'شارك',
            onPressed: hasDocument ? _share : null,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          if (hasDocument)
            IconButton(
              tooltip: 'اقفل الملف',
              onPressed: _close,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: ZakerSpacing.md),
            TrText('بنفتح الملف…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'مقدرناش نفتح الملف',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.folder_open_rounded),
          label: const TrText('اختار ملف تاني'),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: 'مفيش ملف مفتوح',
        message:
            'اختار PDF من الموبايل أو من مكتبتك، وهيتعرض هنا مع الطباعة والمشاركة.',
        action: FilledButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.folder_open_rounded),
          label: const TrText('اختار PDF'),
        ),
      );
    }

    return Column(
      children: [
        _FileBar(
          name: _name ?? widget.fileName ?? 'PDF',
          size: bytes.length,
          onReplace: _pick,
        ),
        const Divider(height: 1),
        Expanded(
          child: PdfPreview(
            build: (_) async => bytes,
            pdfFileName: _shareName,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            useActions: true,
            padding: const EdgeInsets.all(ZakerSpacing.md),
            loadingWidget: const Center(child: CircularProgressIndicator()),
            onError: (context, error) => EmptyState(
              icon: Icons.broken_image_outlined,
              title: 'الصفحات مش ظاهرة',
              message: '$error',
            ),
          ),
        ),
      ],
    );
  }
}

/// The thin bar above the document: file name, size and a replace action.
class _FileBar extends StatelessWidget {
  const _FileBar({
    required this.name,
    required this.size,
    required this.onReplace,
  });

  final String name;
  final int size;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.md,
        vertical: ZakerSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TrText(
                  _formatSize(size),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onReplace,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const TrText('استبدال'),
          ),
        ],
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }
}
