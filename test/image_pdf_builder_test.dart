import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/my_bag/image_pdf_builder.dart';

const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('zaker_img_pdf_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('one A4 page per image, in the order given', () async {
    final first = File('${root.path}/a.png')
      ..writeAsBytesSync(base64Decode(_pngBase64));
    final second = File('${root.path}/b.png')
      ..writeAsBytesSync(base64Decode(_pngBase64));

    final bytes = await buildImagePdf([first.path, second.path]);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 2);
  });

  test('missing files are skipped and an empty list is refused', () async {
    final real = File('${root.path}/a.png')
      ..writeAsBytesSync(base64Decode(_pngBase64));
    final bytes = await buildImagePdf(['${root.path}/gone.png', real.path]);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    await expectLater(
      buildImagePdf(['${root.path}/gone.png']),
      throwsArgumentError,
    );
    await expectLater(buildImagePdf(const []), throwsArgumentError);
  });
}
