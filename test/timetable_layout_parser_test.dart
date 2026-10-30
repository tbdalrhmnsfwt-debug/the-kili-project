import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/timetable_layout_parser.dart';
import 'package:zaker_ai/models/batch_schedule.dart';

void main() {
  const parser = TimetableLayoutParser();

  OcrWord word(
    String text,
    double centerX, {
    double top = 100,
    double confidence = 92,
    String lineId = 'l',
    double width = 60,
  }) =>
      OcrWord(
        text: text,
        left: centerX - width / 2,
        top: top,
        right: centerX + width / 2,
        bottom: top + 30,
        confidence: confidence,
        lineId: lineId,
      );

  OcrLine line(String id, List<OcrWord> words) => OcrLine(id: id, words: words);

  List<OcrWord> header({
    String saturday = 'السبت',
    String sunday = 'الأحد',
    String monday = 'الاثنين',
    double confidence = 92,
  }) =>
      [
        word(saturday, 200, top: 0, confidence: confidence, lineId: 'h'),
        word(sunday, 400, top: 0, confidence: confidence, lineId: 'h'),
        word(monday, 600, top: 0, confidence: confidence, lineId: 'h'),
      ];

  OcrDocument document(List<OcrLine> lines) =>
      OcrDocument(width: 800, height: 600, lines: lines);

  test('reads each cell as a weekly entry with its printed day and times', () {
    final result = parser.parse(
      document([
        line('h', header()),
        line('r1', [
          word('8:00', 40, lineId: 'r1'),
          word('9:30', 110, lineId: 'r1'),
          word('رياضيات', 200, lineId: 'r1'),
        ]),
        line('r2', [
          word('10:00', 40, top: 200, lineId: 'r2'),
          word('11:00', 110, top: 200, lineId: 'r2'),
          word('علوم', 400, top: 200, lineId: 'r2'),
          word('لغة', 630, top: 200, lineId: 'r2'),
          word('عربية', 550, top: 200, lineId: 'r2'),
        ]),
      ]),
    );

    expect(result.entries, hasLength(3));
    expect(result.warnings, isEmpty);
    expect(
      result.entries.map((entry) => entry.dayOfWeek),
      [DateTime.saturday, DateTime.sunday, DateTime.monday],
    );
    expect(result.entries[0].title, 'رياضيات');
    expect(result.entries[0].startMinutes, 8 * 60);
    expect(result.entries[0].endMinutes, 9 * 60 + 30);
    expect(result.entries[1].title, 'علوم');
    expect(result.entries[1].startMinutes, 10 * 60);
    expect(result.entries[2].title, 'لغة عربية');
    for (final entry in result.entries) {
      expect(entry.recurrence, TimetableRecurrence.weekly);
      expect(entry.timeZoneId, isNull);
      expect(entry.weekAnchorDate, isNull);
      expect(entry.allDay, isFalse);
    }
  });

  test('folds Arabic-Indic digits and applies a printed ص marker', () {
    final result = parser.parse(
      document([
        line('h', header()),
        line('r1', [
          word('٨:٠٠', 40, lineId: 'r1'),
          word('ص', 90, lineId: 'r1'),
          word('٩:٣٠', 110, lineId: 'r1'),
          word('ص', 160, lineId: 'r1'),
          word('رياضيات', 200, lineId: 'r1'),
        ]),
      ]),
    );

    expect(result.entries, hasLength(1));
    final entry = result.entries.single;
    expect(entry.startMinutes, 8 * 60);
    expect(entry.endMinutes, 9 * 60 + 30);
    expect(entry.uncertainFields, isEmpty);
  });

  test('folds Devanagari digits and flags the missing end time', () {
    final result = parser.parse(
      document([
        line('h', header()),
        line('r1', [
          word('८:००', 40, lineId: 'r1'),
          word('رياضيات', 200, lineId: 'r1'),
        ]),
      ]),
    );

    expect(result.entries, hasLength(1));
    final entry = result.entries.single;
    expect(entry.startMinutes, 8 * 60);
    expect(entry.endMinutes, entry.startMinutes);
    expect(entry.uncertainFields, contains('endMinutes'));
  });

  test('marks low-confidence text and headers instead of hiding them', () {
    final result = parser.parse(
      document([
        line('h', header(confidence: 40)),
        line('r1', [
          word('8:00', 40, lineId: 'r1'),
          word('9:30', 110, lineId: 'r1'),
          word('رياضيات', 200, confidence: 45, lineId: 'r1'),
        ]),
      ]),
    );

    final entry = result.entries.single;
    expect(entry.confidence, lessThan(0.6));
    expect(entry.uncertainFields, contains('title'));
    expect(entry.uncertainFields, contains('dayOfWeek'));
  });

  test('keeps the time column out of the titles', () {
    final result = parser.parse(
      document([
        line('h', header()),
        line('r1', [
          word('الفترة', 20, lineId: 'r1'),
          word('8:00', 60, lineId: 'r1'),
          word('9:30', 110, lineId: 'r1'),
          word('رياضيات', 200, lineId: 'r1'),
        ]),
      ]),
    );

    expect(result.entries, hasLength(1));
    expect(result.entries.single.title, 'رياضيات');
    expect(
      result.entries.single.title.contains('الفترة'),
      isFalse,
    );
  });

  test('never invents a time when the image has none', () {
    final result = parser.parse(
      document([
        line('h', header()),
        line('r1', [word('رياضيات', 200, lineId: 'r1')]),
      ]),
    );

    expect(result.entries, isEmpty);
    expect(
      result.warnings.any((warning) => warning.contains('مفيش أوقات')),
      isTrue,
    );
  });

  test('falls back to one class per line when there is no day header', () {
    final result = parser.parse(
      document([
        line('l1', [
          word('السبت', 100, lineId: 'l1'),
          word('8:00', 200, lineId: 'l1'),
          word('9:30', 260, lineId: 'l1'),
          word('رياضيات', 350, lineId: 'l1'),
        ]),
      ]),
    );

    expect(result.entries, hasLength(1));
    final entry = result.entries.single;
    expect(entry.dayOfWeek, DateTime.saturday);
    expect(entry.startMinutes, 8 * 60);
    expect(entry.endMinutes, 9 * 60 + 30);
    expect(entry.title, 'رياضيات');
    expect(
      result.warnings.any((warning) => warning.contains('سطور')),
      isTrue,
    );
  });

  test('reads English day names and am markers', () {
    final result = parser.parse(
      document([
        line('h', [
          word('Sat', 200, top: 0, lineId: 'h'),
          word('Sun', 400, top: 0, lineId: 'h'),
        ]),
        line('r1', [
          word('8:00', 40, lineId: 'r1'),
          word('AM', 90, lineId: 'r1'),
          word('9:30', 110, lineId: 'r1'),
          word('AM', 160, lineId: 'r1'),
          word('Math', 200, lineId: 'r1'),
        ]),
      ]),
    );

    final entry = result.entries.single;
    expect(entry.dayOfWeek, DateTime.saturday);
    expect(entry.startMinutes, 8 * 60);
    expect(entry.endMinutes, 9 * 60 + 30);
    expect(entry.title, 'Math');
    expect(entry.uncertainFields, isEmpty);
  });

  test('reports an empty result when no day can be read', () {
    final result = parser.parse(
      document([
        line('l1', [
          word('8:00', 40, lineId: 'l1'),
          word('رياضيات', 200, lineId: 'l1'),
        ]),
      ]),
    );

    expect(result.entries, isEmpty);
    expect(
      result.warnings.any((warning) => warning.contains('مفيش حصص واضحة')),
      isTrue,
    );
  });

  test('a time range that loses its end is flagged, not completed', () {
    final result = parser.parse(
      document([
        line('l1', [
          word('السبت', 100, lineId: 'l1'),
          word('8:00', 200, lineId: 'l1'),
          word('رياضيات', 350, lineId: 'l1'),
        ]),
      ]),
    );

    final entry = result.entries.single;
    expect(entry.endMinutes, entry.startMinutes);
    expect(entry.uncertainFields, contains('endMinutes'));
  });
}
