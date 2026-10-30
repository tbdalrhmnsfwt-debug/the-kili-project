/// Builds one PDF from a list of images: A4, one image per page, centred.
///
/// The scan screen and the bag's boards pocket share this builder so their
/// output cannot drift apart. Unreadable paths are skipped rather than
/// failing the whole document; a list with nothing readable is refused.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildImagePdf(List<String> imagePaths) async {
  final doc = pw.Document();
  var pages = 0;
  for (final path in imagePaths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) continue;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      ),
    );
    pages++;
  }
  if (pages == 0) {
    throw ArgumentError.value(
      imagePaths,
      'imagePaths',
      'no readable image',
    );
  }
  return doc.save();
}
