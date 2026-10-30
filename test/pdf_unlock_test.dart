import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../lib/core/pdf/pdf_unlock.dart';

/// A one-page document locked with «secret».
Future<List<int>> _lockedDocument() async {
  final document = sf.PdfDocument();
  document.pages.add();
  document.security.userPassword = 'secret';
  final bytes = await document.save();
  document.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a correct password writes a copy that opens without one', () async {
    final directory = Directory.systemTemp.createTempSync('zaker_pdf_unlock_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('${directory.path}/locked.pdf')
      ..writeAsBytesSync(await _lockedDocument());
    final output = File('${directory.path}/open.pdf');

    final unlocked = await unlockPdfTo(
      input: input,
      password: 'secret',
      output: output,
    );

    expect(unlocked, isTrue);
    // Syncfusion only builds a document from bytes; the point of the assertion
    // is that the copy no longer needs a password.
    final document = sf.PdfDocument(inputBytes: output.readAsBytesSync());
    expect(document.pages.count, 1);
    document.dispose();
  });

  test('a wrong password writes nothing', () async {
    final directory = Directory.systemTemp.createTempSync('zaker_pdf_unlock_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('${directory.path}/locked.pdf')
      ..writeAsBytesSync(await _lockedDocument());
    final output = File('${directory.path}/open.pdf');

    final unlocked = await unlockPdfTo(
      input: input,
      password: 'nope',
      output: output,
    );

    expect(unlocked, isFalse);
    expect(output.existsSync(), isFalse);
  });
}
