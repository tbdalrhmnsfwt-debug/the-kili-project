import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/hocr_parser.dart';

void main() {
  const parser = HocrParser();

  test('reads the page box, line ids, word boxes and confidence', () {
    const html = '''
<div class='ocr_page' title='image "t.png"; bbox 0 0 1000 800'>
  <span class='ocr_line' id='line_1' title='bbox 100 100 900 150'>
    <span class='ocrx_word' title='bbox 700 100 850 150; x_wconf 93'>السبت</span>
    <span class='ocrx_word' title='bbox 100 100 300 150; x_wconf 88'>رياضيات</span>
  </span>
</div>
''';

    final document = parser.parse(html);

    expect(document.width, 1000);
    expect(document.height, 800);
    expect(document.lines, hasLength(1));
    final line = document.lines.single;
    expect(line.id, 'line_1');
    expect(line.words, hasLength(2));
    expect(line.words[0].text, 'السبت');
    expect(line.words[0].left, 700);
    expect(line.words[0].right, 850);
    expect(line.words[0].confidence, 93);
    expect(line.words[0].lineId, 'line_1');
    expect(line.words[1].text, 'رياضيات');
  });

  test('decodes entities, drops blank words and numbers unnamed lines', () {
    const html = '''
<span class='ocr_line' title='bbox 0 0 500 40'>
  <span class='ocrx_word' title='bbox 0 0 90 40'>A&amp;B</span>
  <span class='ocrx_word' title='bbox 100 0 190 40'>   </span>
  <span class='ocrx_word' title='bbox 200 0 290 40'>&#x645;&#1606;&#1607;</span>
</span>
<span class='ocr_line' title='bbox 0 60 500 100'>
  <span class='ocrx_word' title='bbox 0 60 90 100'>C</span>
</span>
''';

    final document = parser.parse(html);

    expect(document.lines, hasLength(2));
    expect(document.lines[0].id, 'line-1');
    expect(document.lines[0].words.map((word) => word.text), ['A&B', 'منه']);
    expect(document.lines[0].words.every((w) => w.lineId == 'line-1'), isTrue);
    expect(document.lines[1].id, 'line-2');
  });

  test('keeps the line open across housekeeping spans', () {
    const html = '''
<span class='ocrx_line' id='r' title='bbox 0 0 400 40'>
  <span class='ocrx_cinfo' title='x_size 12; x_descenders 2'></span>
  <span class='ocrx_word' title='bbox 0 0 100 40'>A</span>
</span>
''';

    final document = parser.parse(html);

    expect(document.lines, hasLength(1));
    expect(document.lines.single.words.single.text, 'A');
  });

  test('keeps the words of a truncated response', () {
    const html = '''
<span class='ocr_line' id='l' title='bbox 0 0 400 40'>
  <span class='ocrx_word' title='bbox 0 0 100 40'>نص
''';

    final document = parser.parse(html);

    expect(document.lines, hasLength(1));
    expect(document.lines.single.words.single.text, 'نص');
  });

  test('returns an empty document for empty or unrelated markup', () {
    for (final html in ['', '   ', 'not html at all', '<div>hi</div>']) {
      final document = parser.parse(html);
      expect(document.lines, isEmpty);
      expect(document.width, 0);
      expect(document.height, 0);
    }
  });

  test('falls back to word bounds when the page has no box', () {
    const html = '''
<span class='ocr_line' title='bbox 10 20 300 90'>
  <span class='ocrx_word' title='bbox 10 20 300 90; x_wconf 70'>كلمة</span>
</span>
''';

    final document = parser.parse(html);

    expect(document.width, 300);
    expect(document.height, 90);
    expect(document.lines.single.words.single.confidence, 70);
  });
}
