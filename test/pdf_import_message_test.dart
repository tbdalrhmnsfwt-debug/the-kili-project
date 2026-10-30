import 'package:flutter_test/flutter_test.dart';

import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/features/pdf/widgets/pdf_import_button.dart';

void main() {
  test('a pass rejected for space says so instead of "not a PDF"', () {
    expect(
      pdfImportMessage(
        added: 0,
        failures: const [PdfImportFailure.storage],
      ),
      'مفيش مساحة كافية على الجهاز — الملفات ما اتضافتش.',
    );
  });

  test('a pass rejected as non-PDF keeps the format message', () {
    expect(
      pdfImportMessage(
        added: 0,
        failures: const [PdfImportFailure.invalidHeader],
      ),
      'مفيش ملفات اتضافت — اتأكد إنهم PDF.',
    );
  });

  test('a mixed pass reports both counts', () {
    expect(
      pdfImportMessage(added: 2, failures: const [PdfImportFailure.storage]),
      'تمت إضافة 2 ملف، و1 ملف اتترفض.',
    );
  });
}
