/// Reads a timetable out of one OCR result.
///
/// The parser only reports what the image prints: a day header supplies the
/// columns, time tokens supply the rows, and a cell's words become the title.
/// A missing time or a low-confidence word is labelled, never guessed, and no
/// date, timezone or recurrence anchor is invented. A grid that cannot be
/// reconstructed is returned empty with a warning for the review screen.
library;

import 'dart:math' as math;

import '../../models/batch_schedule.dart';

/// What one image yielded, plus the Arabic warnings the review screen shows.
class TimetableParseResult {
  const TimetableParseResult({required this.entries, required this.warnings});

  final List<TimetableEntry> entries;
  final List<String> warnings;

  bool get isEmpty => entries.isEmpty;
}

class TimetableLayoutParser {
  const TimetableLayoutParser();

  /// Below this Tesseract confidence the word is shown as uncertain.
  static const double _lowConfidence = 60;

  static const int _maxTitleChars = 120;

  TimetableParseResult parse(OcrDocument document) {
    if (document.lines.isEmpty) {
      return const TimetableParseResult(
        entries: [],
        warnings: ['مفيش كلام مقروء في صورة الجدول.'],
      );
    }

    final warnings = <String>[];
    final header = _findHeader(document);

    if (header != null) {
      final grid = _parseGrid(document, header, warnings);
      if (grid.isNotEmpty) return _result(grid, warnings);
      warnings.add('لقينا أسماء الأيام بس مقدرناش نربط الحصص بأوقاتها.');
    } else {
      warnings.add('مش لاقيين صف أسماء أيام؛ بنجرّب نقرا كل سطر لوحده.');
    }

    final lines = _parseLines(document, skipLineId: header?.line.id);
    if (lines.isNotEmpty) {
      warnings.add('الجدول اتقري كسطور منفصلة، راجع كل حصة قبل النشر.');
      return _result(lines, warnings);
    }

    warnings.add('مفيش حصص واضحة في الصورة. لازم تدخل الجدول بنفسك.');
    return _result(const [], warnings);
  }

  // ------------------------------------------------------------------- header

  _DayHeader? _findHeader(OcrDocument document) {
    _DayHeader? best;
    for (final line in document.lines) {
      final cells = <_DayCell>[
        for (final word in line.words)
          if (_dayOf(word.text) case final day?) _DayCell(day: day, word: word),
      ];
      final distinct = {for (final cell in cells) cell.day};
      if (distinct.length < 2) continue;
      if (best == null || distinct.length > best.dayCount) {
        best = _DayHeader(
          line: line,
          cells: cells,
          dayCount: distinct.length,
        );
      }
    }
    return best;
  }

  // --------------------------------------------------------------------- grid

  List<TimetableEntry> _parseGrid(
    OcrDocument document,
    _DayHeader header,
    List<String> warnings,
  ) {
    final columns = [...header.cells]
      ..sort((a, b) => a.word.centerX.compareTo(b.word.centerX));
    final centers = [for (final column in columns) column.word.centerX];
    final spacing = _medianGap(centers);
    if (spacing <= 0) {
      warnings.add('أسماء الأيام كلها في نفس المكان، مش قادرين نحدد الأعمدة.');
      return const [];
    }
    final half = spacing / 2;
    final leftEdge = centers.first - half;
    final rightEdge = centers.last + half;

    final rows = <_Row>[];
    for (final line in document.lines) {
      final times = _timesOn(line);
      if (times.isEmpty) continue;
      times.sort((a, b) => a.minutes.compareTo(b.minutes));
      rows.add(
        _Row(
          line: line,
          start: times.first,
          // The latest token on the line is the end; a lone token leaves it
          // absent so the entry is visibly incomplete instead of invented.
          end: times.length > 1 ? times.last : null,
        ),
      );
    }
    if (rows.isEmpty) {
      warnings.add('مفيش أوقات واضحة في الصورة؛ الجدول محتاج تعديل يدوي.');
      return const [];
    }
    rows.sort((a, b) {
      final byStart = a.start.minutes.compareTo(b.start.minutes);
      return byStart != 0 ? byStart : a.centerY.compareTo(b.centerY);
    });

    final rowCenters = [for (final row in rows) row.centerY];
    final rowSpacing = _medianGap([...rowCenters]..sort());
    final tolerance = rowSpacing > 0 ? math.max(24.0, rowSpacing * 0.75) : 64.0;

    final cells = <(int, int), List<OcrWord>>{};
    var skipped = 0;
    for (final line in document.lines) {
      if (line.id == header.line.id) continue;
      for (final word in line.words) {
        if (_dayOf(word.text) != null) continue;
        if (_isTimeWord(word.text) || _isMeridian(word.text)) continue;
        final x = word.centerX;
        if (x < leftEdge || x > rightEdge) continue;
        final row = _nearest(rowCenters, word.centerY, tolerance);
        if (row == null) {
          skipped += 1;
          continue;
        }
        final column = _nearestIndex(centers, x);
        cells.putIfAbsent((row, column), () => []).add(word);
      }
    }
    if (skipped > 0) {
      warnings
          .add('فيه كلمات مش تابعة لصف واضح، وسيبناها بدل ما نخمّن مكانها.');
    }

    final keys = cells.keys.toList()
      ..sort((a, b) {
        final row = a.$1.compareTo(b.$1);
        return row != 0 ? row : a.$2.compareTo(b.$2);
      });

    final entries = <TimetableEntry>[];
    var index = 0;
    for (final key in keys) {
      final words = cells[key]!;
      final title = _cellText(words);
      if (title.isEmpty) continue;
      final row = rows[key.$1];
      final column = columns[key.$2];
      index += 1;

      final uncertain = <String>{};
      final start = row.start;
      final end = row.end;
      if (end == null || end.minutes <= start.minutes) {
        uncertain.add('endMinutes');
      }
      if (!start.explicitMeridian) uncertain.add('startMinutes');
      if (end != null && !end.explicitMeridian) uncertain.add('endMinutes');
      if (column.word.confidence < _lowConfidence) uncertain.add('dayOfWeek');
      final confidence = math.min(
            _minConfidence(words),
            column.word.confidence,
          ) /
          100;
      if (confidence < 0.6) uncertain.add('title');

      entries.add(
        TimetableEntry(
          id: 'slot-$index',
          dayOfWeek: column.day,
          startMinutes: start.minutes,
          endMinutes: end != null && end.minutes > start.minutes
              ? end.minutes
              : start.minutes,
          title: title,
          confidence: confidence,
          uncertainFields: uncertain.toList()..sort(),
          recurrence: TimetableRecurrence.weekly,
        ),
      );
    }
    return entries;
  }

  // ------------------------------------------------------------ line fallback

  List<TimetableEntry> _parseLines(
    OcrDocument document, {
    String? skipLineId,
  }) {
    final entries = <TimetableEntry>[];
    var index = 0;
    for (final line in document.lines) {
      if (line.id == skipLineId) continue;
      int? day;
      for (final word in line.words) {
        day = _dayOf(word.text);
        if (day != null) break;
      }
      if (day == null) continue;
      final times = _timesOn(line);
      if (times.isEmpty) continue;
      times.sort((a, b) => a.minutes.compareTo(b.minutes));
      final titleWords = [
        for (final word in line.words)
          if (_dayOf(word.text) == null &&
              !_isTimeWord(word.text) &&
              !_isMeridian(word.text))
            word,
      ];
      final title = _cellText(titleWords);
      if (title.isEmpty) continue;
      index += 1;
      final start = times.first;
      final end = times.length > 1 ? times.last : null;
      final uncertain = <String>{
        if (end == null || end.minutes <= start.minutes) 'endMinutes',
        if (!start.explicitMeridian) 'startMinutes',
        if (end != null && !end.explicitMeridian) 'endMinutes',
      };
      entries.add(
        TimetableEntry(
          id: 'slot-$index',
          dayOfWeek: day,
          startMinutes: start.minutes,
          endMinutes: end != null && end.minutes > start.minutes
              ? end.minutes
              : start.minutes,
          title: title,
          confidence: _minConfidence(titleWords) / 100,
          uncertainFields: uncertain.toList()..sort(),
          recurrence: TimetableRecurrence.weekly,
        ),
      );
    }
    return entries;
  }

  // -------------------------------------------------------------------- times

  List<_ParsedTime> _timesOn(OcrLine line) {
    final words = [...line.words]
      ..sort((a, b) => a.centerX.compareTo(b.centerX));
    final times = <_ParsedTime>[];
    for (var i = 0; i < words.length; i++) {
      final hint = _meridianOf(words[i].text) ?? _neighbourMeridian(words, i);
      for (final part in _splitRange(words[i].text)) {
        final parsed = _parseTime(part, hint);
        if (parsed != null) times.add(parsed);
      }
    }
    return times;
  }

  _Meridian? _neighbourMeridian(List<OcrWord> words, int index) {
    if (index + 1 < words.length) {
      final next = _meridianOf(words[index + 1].text);
      if (next != null) return next;
    }
    if (index > 0) return _meridianOf(words[index - 1].text);
    return null;
  }

  static final RegExp _timePattern =
      RegExp(r'^(\d{1,2})[:.٫](\d{2})(ص|م|am|pm)?$');
  static final RegExp _bareHour = RegExp(r'^(\d{1,2})(ص|م|am|pm)?$');

  _ParsedTime? _parseTime(String raw, _Meridian? hint) {
    var text = _foldDigits(raw).trim().toLowerCase();
    text = text.replaceAll(RegExp(r'[ً-ْٰـ]'), '');
    text = _stripEdges(text);
    if (text.isEmpty) return null;

    var meridian = hint;
    final match = _timePattern.firstMatch(text);
    int hour;
    int minute;
    if (match != null) {
      hour = int.parse(match.group(1)!);
      minute = int.parse(match.group(2)!);
      meridian = _meridianOf(match.group(3) ?? '') ?? meridian;
    } else {
      final bare = _bareHour.firstMatch(text);
      if (bare == null || hint == null) return null;
      hour = int.parse(bare.group(1)!);
      minute = 0;
      meridian = _meridianOf(bare.group(2) ?? '') ?? hint;
    }
    if (hour > 23 || minute > 59) return null;

    var explicit = meridian != null;
    if (meridian != null) {
      if (hour > 12) {
        // A 24-hour time with a stray marker is left as printed.
        explicit = false;
      } else if (meridian == _Meridian.pm) {
        if (hour < 12) hour += 12;
      } else if (hour == 12) {
        hour = 0;
      }
    }
    return _ParsedTime(
      minutes: hour * 60 + minute,
      explicitMeridian: explicit,
    );
  }

  static List<String> _splitRange(String raw) {
    final normalized = _foldDigits(raw);
    return normalized
        .split(RegExp(r'[-–—~]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  bool _isTimeWord(String raw) {
    for (final part in _splitRange(raw)) {
      final text = _stripEdges(
        _foldDigits(part)
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[ً-ْٰـ]'), ''),
      );
      if (_timePattern.hasMatch(text)) return true;
    }
    return false;
  }

  static _Meridian? _meridianOf(String raw) {
    final text = _stripEdges(raw.trim().toLowerCase());
    return switch (text) {
      'ص' || 'am' => _Meridian.am,
      'م' || 'pm' => _Meridian.pm,
      _ => null,
    };
  }

  bool _isMeridian(String raw) => _meridianOf(raw) != null;

  // ----------------------------------------------------------------- day names

  static const Map<String, int> _days = {
    'السبت': 6,
    'سبت': 6,
    'sat': 6,
    'saturday': 6,
    'الاحد': 7,
    'احد': 7,
    'sun': 7,
    'sunday': 7,
    'الاثنين': 1,
    'الاتنين': 1,
    'اثنين': 1,
    'mon': 1,
    'monday': 1,
    'الثلاثاء': 2,
    'الثلاثا': 2,
    'ثلاثاء': 2,
    'ثلاثا': 2,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'الاربعاء': 3,
    'الاربعا': 3,
    'اربعاء': 3,
    'اربعا': 3,
    'wed': 3,
    'wednesday': 3,
    'الخميس': 4,
    'خميس': 4,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'thursday': 4,
    'الجمعه': 5,
    'جمعه': 5,
    'fri': 5,
    'friday': 5,
  };

  static int? _dayOf(String raw) => _days[_dayKey(raw)];

  static String _dayKey(String raw) {
    var text = _foldDigits(raw).trim().toLowerCase();
    text = text.replaceAll(RegExp(r'[ً-ْٰـ]'), '');
    text = text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
    text = _stripEdges(text);
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  // ---------------------------------------------------------------- cell text

  String _cellText(List<OcrWord> words) {
    if (words.isEmpty) return '';
    final groups = <String, List<OcrWord>>{};
    for (final word in words) {
      final key = word.lineId.isEmpty ? 'y-${word.top.round()}' : word.lineId;
      groups.putIfAbsent(key, () => []).add(word);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => _topOf(a).compareTo(_topOf(b)));

    final parts = <String>[];
    for (final group in ordered) {
      final rtl = _looksRtl(group);
      group.sort(
        (a, b) => rtl
            ? b.centerX.compareTo(a.centerX)
            : a.centerX.compareTo(b.centerX),
      );
      final text = _clean(group.map((word) => word.text).join(' '));
      if (text.isNotEmpty) parts.add(text);
    }
    var title = _clean(parts.join(' '));
    if (title.runes.length > _maxTitleChars) {
      title =
          String.fromCharCodes(title.runes.take(_maxTitleChars)).trimRight();
    }
    return title;
  }

  static double _topOf(List<OcrWord> words) =>
      words.map((word) => word.top).reduce(math.min);

  static String _clean(String text) => text
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// True when the first letter with a direction is Arabic or Hebrew.
  static bool _looksRtl(List<OcrWord> words) {
    for (final word in words) {
      for (final rune in word.text.runes) {
        if (_isRtlLetter(rune)) return true;
        if (_isLatinLetter(rune)) return false;
      }
    }
    return false;
  }

  static bool _isRtlLetter(int rune) =>
      (rune >= 0x0590 && rune <= 0x05FF) ||
      (rune >= 0x0600 && rune <= 0x06FF) ||
      (rune >= 0x0750 && rune <= 0x077F) ||
      (rune >= 0x08A0 && rune <= 0x08FF) ||
      (rune >= 0xFB50 && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFF);

  static bool _isLatinLetter(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);

  // -------------------------------------------------------------------- misc

  static double _minConfidence(List<OcrWord> words) {
    if (words.isEmpty) return 0;
    return words
        .map((word) => word.confidence)
        .reduce(math.min)
        .clamp(0, 100)
        .toDouble();
  }

  static int? _nearest(List<double> centers, double value, double tolerance) {
    if (centers.isEmpty) return null;
    var best = 0;
    var distance = (centers[0] - value).abs();
    for (var i = 1; i < centers.length; i++) {
      final candidate = (centers[i] - value).abs();
      if (candidate < distance) {
        best = i;
        distance = candidate;
      }
    }
    return distance <= tolerance ? best : null;
  }

  static int _nearestIndex(List<double> centers, double value) {
    var best = 0;
    var distance = (centers[0] - value).abs();
    for (var i = 1; i < centers.length; i++) {
      final candidate = (centers[i] - value).abs();
      if (candidate < distance) {
        best = i;
        distance = candidate;
      }
    }
    return best;
  }

  static double _medianGap(List<double> sorted) {
    if (sorted.length < 2) return 0;
    final gaps = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i] - sorted[i - 1];
      if (gap > 0) gaps.add(gap);
    }
    if (gaps.isEmpty) return 0;
    gaps.sort();
    return gaps[gaps.length ~/ 2];
  }

  static String _foldDigits(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      if ((rune >= 0x0660 && rune <= 0x0669) ||
          (rune >= 0x06F0 && rune <= 0x06F9)) {
        buffer.writeCharCode(0x30 + (rune & 0xF));
      } else if (rune >= 0x0966 && rune <= 0x096F) {
        buffer.writeCharCode(0x30 + rune - 0x0966);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static final RegExp _edges = RegExp(
    r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
    unicode: true,
  );

  static String _stripEdges(String text) => text.replaceAll(_edges, '');

  TimetableParseResult _result(
    List<TimetableEntry> entries,
    List<String> warnings,
  ) {
    final sorted = [...entries]..sort((a, b) {
        final byDay = _weekOrder(a.dayOfWeek).compareTo(
          _weekOrder(b.dayOfWeek),
        );
        if (byDay != 0) return byDay;
        final byStart = a.startMinutes.compareTo(b.startMinutes);
        return byStart != 0 ? byStart : a.title.compareTo(b.title);
      });
    final unique = <String>[];
    for (final warning in warnings) {
      if (warning.isNotEmpty && !unique.contains(warning)) unique.add(warning);
    }
    return TimetableParseResult(
      entries: List.unmodifiable(sorted),
      warnings: List.unmodifiable(unique),
    );
  }

  /// Saturday is the first day of the week shown in local timetables.
  static int _weekOrder(int dayOfWeek) => (dayOfWeek - 6) % 7;
}

enum _Meridian { am, pm }

class _ParsedTime {
  const _ParsedTime({required this.minutes, required this.explicitMeridian});

  final int minutes;
  final bool explicitMeridian;
}

class _DayCell {
  const _DayCell({required this.day, required this.word});

  final int day;
  final OcrWord word;
}

class _DayHeader {
  const _DayHeader({
    required this.line,
    required this.cells,
    required this.dayCount,
  });

  final OcrLine line;
  final List<_DayCell> cells;
  final int dayCount;
}

class _Row {
  const _Row({required this.line, required this.start, required this.end});

  final OcrLine line;
  final _ParsedTime start;
  final _ParsedTime? end;

  double get centerY {
    final words = line.words;
    if (words.isEmpty) return 0;
    return words.map((word) => word.centerY).reduce((a, b) => a + b) /
        words.length;
  }
}
