/// Parses Tesseract hOCR into the [OcrDocument] the timetable parser reads.
///
/// The parser keeps every word's pixel box and confidence, joins nothing and
/// reorders nothing: reading direction belongs to the layout stage, which can
/// see the whole line. Malformed markup yields whatever words were complete
/// rather than throwing, because a bad OCR response must not lose the draft.
library;

import '../../models/batch_schedule.dart';

class HocrParser {
  const HocrParser();

  static const Set<String> _lineClasses = {
    'ocr_line',
    'ocrx_line',
    'ocr_header',
    'ocr_caption',
    'ocr_textfloat',
  };

  static const Set<String> _wordClasses = {'ocrx_word', 'ocr_word'};

  OcrDocument parse(String html) {
    if (html.trim().isEmpty) {
      return const OcrDocument(width: 0, height: 0, lines: []);
    }

    final spans = <_Frame>[];
    final lines = <OcrLine>[];
    double pageWidth = 0;
    double pageHeight = 0;
    var generatedLine = 0;

    void addLine(_LineBuilder builder) {
      if (builder.words.isEmpty) return;
      lines.add(
        OcrLine(
          id: builder.id,
          words: List.unmodifiable(builder.words),
        ),
      );
    }

    void finishWord(_WordBuilder builder) {
      final text = builder.text.toString().trim();
      if (text.isEmpty) return;
      _LineBuilder? owner;
      for (var i = spans.length - 1; i >= 0; i--) {
        final line = spans[i].line;
        if (line != null) {
          owner = line;
          break;
        }
      }
      if (owner == null) return;
      owner.words.add(
        OcrWord(
          text: text,
          left: builder.left,
          top: builder.top,
          right: builder.right,
          bottom: builder.bottom,
          confidence: builder.confidence,
          lineId: owner.id,
        ),
      );
    }

    void closeFrame(_Frame frame) {
      final word = frame.word;
      if (word != null) finishWord(word);
      final line = frame.line;
      if (line != null) addLine(line);
    }

    final tokens = RegExp(r'<[^>]*>|[^<]+').allMatches(html);
    for (final token in tokens) {
      final raw = token.group(0)!;
      if (!raw.startsWith('<')) {
        _WordBuilder? word;
        for (var i = spans.length - 1; i >= 0; i--) {
          if (spans[i].word != null) {
            word = spans[i].word;
            break;
          }
        }
        word?.text.write(_decodeEntities(raw));
        continue;
      }

      final closing = RegExp(r'^<\s*/\s*([a-zA-Z][\w:-]*)').firstMatch(raw);
      if (closing != null) {
        if (closing.group(1)!.toLowerCase() == 'span' && spans.isNotEmpty) {
          closeFrame(spans.removeLast());
        }
        continue;
      }

      final opening = RegExp(r'^<\s*([a-zA-Z][\w:-]*)').firstMatch(raw);
      if (opening == null) continue;
      final tag = opening.group(1)!.toLowerCase();
      final classes = _classNames(raw);
      final title = _attribute(raw, 'title');

      if (classes.contains('ocr_page')) {
        final box = _bbox(title);
        if (box != null) {
          if (box.width > pageWidth) pageWidth = box.width;
          if (box.height > pageHeight) pageHeight = box.height;
        }
        continue;
      }

      final isLine = classes.any(_lineClasses.contains);
      final isWord = classes.any(_wordClasses.contains);
      if (tag != 'span') continue;

      final selfClosing = raw.trimRight().endsWith('/>');
      if (!isLine && !isWord) {
        // hOCR nests housekeeping spans (ocrx_cinfo and friends) that carry no
        // words. Their closing tag must not close the line containing them,
        // so each one gets a frame of its own that closes to nothing.
        if (!selfClosing) spans.add(_Frame.ignored());
        continue;
      }

      if (isLine) {
        final box = _bbox(title);
        var id = _attribute(raw, 'id') ?? '';
        if (id.isEmpty) {
          generatedLine += 1;
          id = 'line-$generatedLine';
        }
        final frame = _Frame(
          _LineBuilder(
            id: id,
            left: box?.left ?? 0,
            top: box?.top ?? 0,
            right: box?.right ?? 0,
            bottom: box?.bottom ?? 0,
          ),
        );
        if (selfClosing) {
          closeFrame(frame);
        } else {
          spans.add(frame);
        }
      } else {
        final box = _bbox(title) ?? const _Box(0, 0, 0, 0);
        final frame = _Frame.word(
          _WordBuilder(
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
            confidence: _confidence(title),
          ),
        );
        if (selfClosing) {
          closeFrame(frame);
        } else {
          spans.add(frame);
        }
      }
    }

    // A truncated response may leave spans open; keep what was recognised.
    while (spans.isNotEmpty) {
      closeFrame(spans.removeLast());
    }

    if (pageWidth <= 0 || pageHeight <= 0) {
      for (final line in lines) {
        for (final word in line.words) {
          if (word.right > pageWidth) pageWidth = word.right;
          if (word.bottom > pageHeight) pageHeight = word.bottom;
        }
      }
    }

    return OcrDocument(
      width: pageWidth,
      height: pageHeight,
      lines: List.unmodifiable(lines),
    );
  }

  static Set<String> _classNames(String tag) {
    final value = _attribute(tag, 'class');
    if (value == null) return const <String>{};
    return {
      for (final name in value.split(RegExp(r'\s+')))
        if (name.isNotEmpty) name.toLowerCase(),
    };
  }

  static String? _attribute(String tag, String name) {
    final match = RegExp(
      '$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
      caseSensitive: false,
    ).firstMatch(tag);
    if (match == null) return null;
    return match.group(1) ?? match.group(2) ?? '';
  }

  static final RegExp _bboxPattern = RegExp(
    r'bbox\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+'
    r'(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)',
  );

  static _Box? _bbox(String? title) {
    if (title == null) return null;
    final match = _bboxPattern.firstMatch(title);
    if (match == null) return null;
    final left = double.parse(match.group(1)!);
    final top = double.parse(match.group(2)!);
    final right = double.parse(match.group(3)!);
    final bottom = double.parse(match.group(4)!);
    if (right < left || bottom < top) return null;
    return _Box(left, top, right, bottom);
  }

  static double _confidence(String? title) {
    if (title == null) return 0;
    final match = RegExp(r'x_wconf\s+(-?\d+(?:\.\d+)?)').firstMatch(title);
    if (match == null) return 0;
    final value = double.parse(match.group(1)!);
    return value.clamp(0, 100).toDouble();
  }

  static final RegExp _namedEntity = RegExp(r'&(amp|lt|gt|quot|apos|nbsp);');
  static final RegExp _decimalEntity = RegExp(r'&#(\d+);');
  static final RegExp _hexEntity = RegExp(r'&#x([0-9a-fA-F]+);');

  static String _decodeEntities(String raw) {
    if (!raw.contains('&')) return raw;
    var text = raw;
    text = text.replaceAllMapped(_hexEntity, (match) {
      final value = int.tryParse(match.group(1)!, radix: 16);
      return value == null ? match.group(0)! : String.fromCharCode(value);
    });
    text = text.replaceAllMapped(_decimalEntity, (match) {
      final value = int.tryParse(match.group(1)!);
      return value == null ? match.group(0)! : String.fromCharCode(value);
    });
    text = text.replaceAllMapped(_namedEntity, (match) {
      return switch (match.group(1)) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        _ => ' ',
      };
    });
    return text;
  }
}

class _Box {
  const _Box(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
}

class _Frame {
  _Frame(this.line) : word = null;

  _Frame.word(this.word) : line = null;

  _Frame.ignored()
      : line = null,
        word = null;

  final _LineBuilder? line;
  final _WordBuilder? word;
}

class _LineBuilder {
  _LineBuilder({
    required this.id,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String id;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final List<OcrWord> words = [];
}

class _WordBuilder {
  _WordBuilder({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double confidence;
  final StringBuffer text = StringBuffer();
}
