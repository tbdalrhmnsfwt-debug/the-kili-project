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
import '../../../providers/pdf_providers.dart';
import '../../../widgets/tr_text.dart';

/// Opens the PDF picker and imports everything chosen.
Future<void> importPdfFiles(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(pdfLibraryControllerProvider.notifier);
  if (controller.isBusy) return;

  final FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withReadStream: true,
    );
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: TrText('مقدرناش نفتح اختيار الملفات.')),
    );
    return;
  }
  if (picked == null || picked.files.isEmpty) return;

  final sources = <PdfImportSource>[];
  var unreadable = 0;
  for (final file in picked.files) {
    final stream = file.readStream;
    final path = file.path;
    if (stream == null && path == null) {
      unreadable += 1;
      continue;
    }
    sources.add(
      PdfImportSource(
        name: file.name,
        sizeBytes: file.size,
        openRead: () => stream ?? File(path!).openRead(),
      ),
    );
  }
  if (sources.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: TrText('مقدرناش نقرا الملفات المختارة.')),
    );
    return;
  }

  final result = await controller.import(sources);
  final added = result.imported.length;
  final rejected = result.failures.length + unreadable;
  final message = switch ((added, rejected)) {
    (0, _) => 'مفيش ملفات اتضافت — اتأكد إنهم PDF.',
    (_, 0) => 'تمت إضافة $added ملف.',
    _ => 'تمت إضافة $added ملف، و$rejected ملف اتترفض.',
  };
  messenger.showSnackBar(SnackBar(content: TrText(message)));
}
