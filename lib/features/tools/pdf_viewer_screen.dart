/// The legacy PDF viewer entry point.
///
/// The reader itself lives in `lib/features/pdf/pdf_reader_screen.dart`; this
/// adapter keeps every existing call site working:
///   * `/pdf-viewer?path=...&title=...` (official books and other files),
///   * `PdfViewerScreen(bytes: ...)` from the subject screen,
///   * `PdfViewerScreen(path: ...)` from older flows.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/router.dart';
import '../pdf/pdf_reader_screen.dart';

/// A full-screen PDF reader.
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    this.path,
    this.title,
    this.bytes,
    this.fileName,
    this.docId,
  });

  /// A local file path to open on first build.
  final String? path;

  /// The fallback title shown in the app bar.
  final String? title;

  /// Bytes to display directly (used when another screen already has them).
  final Uint8List? bytes;

  /// The document name used when sharing. Defaults to the picked file name.
  final String? fileName;

  /// A library entry to open.
  final String? docId;

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
  Widget build(BuildContext context) {
    return PdfReaderScreen(
      path: path,
      title: title,
      bytes: bytes,
      fileName: fileName,
      docId: docId,
    );
  }
}
