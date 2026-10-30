/// Picking PDFs and handing them to the library.
///
/// The picker is the only place the app reads a file the user chose. Files are
/// streamed straight into app-private storage; nothing leaves the device and
/// the original is never modified.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pdf/pdf_library_controller.dart';
import '../../../models/pdf_document.dart';
import '../../../providers/pdf_providers.dart';
import '../../../widgets/tr_text.dart';

/// Asks the system for PDF files and returns them as import sources.
typedef PdfPicker = Future<List<PdfImportSource>> Function();

/// The real picker. Unreadable picks are skipped; a cancel returns an empty
/// list, which is not an error.
Future<List<PdfImportSource>> _pickWithSystemPicker() async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    allowMultiple: true,
    withReadStream: true,
  );
  if (picked == null || picked.files.isEmpty) return const [];

  final sources = <PdfImportSource>[];
  for (final file in picked.files) {
    final stream = file.readStream;
    final path = file.path;
    if (stream == null && path == null) continue;
    sources.add(
      PdfImportSource(
        name: file.name,
        sizeBytes: file.size,
        openRead: () => stream ?? File(path!).openRead(),
      ),
    );
  }
  return sources;
}

/// The picker seam: tests replace it with a source that needs no platform
/// channel.
final pdfPickerProvider = Provider<PdfPicker>(
  (ref) => _pickWithSystemPicker,
);

/// Opens the PDF picker, imports everything chosen and returns what landed in
/// the library.
Future<List<PdfDocumentEntry>> importPdfFiles(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(pdfLibraryControllerProvider.notifier);
  if (controller.isBusy) return const [];

  final List<PdfImportSource> sources;
  try {
    sources = await ref.read(pdfPickerProvider)();
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: TrText('مقدرناش نفتح اختيار الملفات.')),
    );
    return const [];
  }
  if (sources.isEmpty) return const [];

  final result = await controller.import(sources);
  final added = result.imported.length;
  final rejected = result.failures.length;
  final message = switch ((added, rejected)) {
    (0, _) => 'مفيش ملفات اتضافت — اتأكد إنهم PDF.',
    (_, 0) => 'تمت إضافة $added ملف.',
    _ => 'تمت إضافة $added ملف، و$rejected ملف اتترفض.',
  };
  messenger.showSnackBar(SnackBar(content: TrText(message)));
  return result.imported;
}
