/// Proves that a study-tool citation exists on the page it claims.
///
/// The generators quote the source verbatim, but OCR, PDF line breaks and
/// Arabic letter variants would make a naive `contains` reject real quotes and
/// accept near-misses. Everything is compared after one shared normalisation:
/// diacritics and tatweel removed, alef/ya/ta variants folded, Arabic-Indic
/// digits converted, punctuation collapsed to single spaces.
library;

import '../../models/study_source.dart';

/// Why an excerpt failed to match.
enum EvidenceFailure {
  none,
  emptyExcerpt,

  /// The cited page is not in the document.
  pageMissing,

  /// The page exists but has no text, so nothing can be proven from it.
  pageEmpty,

  /// The page exists and has text, but the excerpt is not on it.
  notFound,
}

/// The outcome of checking one excerpt against one page.
class EvidenceResult {
  const EvidenceResult.found(this.page) : failure = EvidenceFailure.none;

  const EvidenceResult.failed(this.failure, {this.page});

  final EvidenceFailure failure;

  /// The cited page number, when it exists.
  final int? page;

  bool get isFound => failure == EvidenceFailure.none;
}

class EvidenceValidator {
  const EvidenceValidator._();

  /// Short excerpts cannot prove anything: a two-letter match is noise.
  static const int minimumExcerptChars = 8;

  /// Folds [value] for comparison only. Never display the result.
  static String normalize(String value) {
    if (value.isEmpty) return '';
    final folded = StringBuffer();
    var pendingSpace = false;
    for (final rune in value.runes) {
      final digit = _asciiDigit(rune);
      if (digit != null) {
        if (pendingSpace && folded.isNotEmpty) folded.write(' ');
        pendingSpace = false;
        folded.write(digit);
        continue;
      }
      if (_isIgnoredMark(rune)) continue;
      final letter = _foldLetter(rune);
      if (letter != null) {
        if (pendingSpace && folded.isNotEmpty) folded.write(' ');
        pendingSpace = false;
        folded.writeCharCode(letter);
        continue;
      }
      if (_isContentRune(rune)) {
        if (pendingSpace && folded.isNotEmpty) folded.write(' ');
        pendingSpace = false;
        folded.writeCharCode(rune);
        continue;
      }
      pendingSpace = true;
    }
    return folded.toString().toLowerCase();
  }

  /// True when [excerpt] appears on [pageText] after normalisation.
  static bool contains(String pageText, String excerpt) {
    final needle = normalize(excerpt);
    if (needle.length < minimumExcerptChars) return false;
    return normalize(pageText).contains(needle);
  }

  /// Checks one citation. The document is the only authority: a page the
  /// document does not contain cannot support an excerpt.
  static EvidenceResult verify(
    SourceDocument document, {
    required int page,
    required String excerpt,
  }) {
    if (excerpt.trim().length < minimumExcerptChars) {
      return const EvidenceResult.failed(EvidenceFailure.emptyExcerpt);
    }
    final source = document.page(page);
    if (source == null) {
      return const EvidenceResult.failed(EvidenceFailure.pageMissing);
    }
    if (normalize(source.text).isEmpty) {
      return EvidenceResult.failed(EvidenceFailure.pageEmpty, page: page);
    }
    if (!contains(source.text, excerpt)) {
      return EvidenceResult.failed(EvidenceFailure.notFound, page: page);
    }
    return EvidenceResult.found(page);
  }

  /// A readable window around a match, clamped to [text] and collapsed to one
  /// line. Used to quote evidence without carrying a whole page.
  static String excerptAround(
    String text, {
    required int start,
    required int end,
    int before = 60,
    int after = 100,
  }) {
    final from = (start - before).clamp(0, text.length);
    final to = (end + after).clamp(0, text.length);
    final window = text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ');
    return window.trim();
  }

  /// 0-9 for Arabic-Indic and Eastern Arabic-Indic digits, else null.
  static int? _asciiDigit(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return rune;
    if (rune >= 0x0660 && rune <= 0x0669) return 0x30 + (rune - 0x0660);
    if (rune >= 0x06F0 && rune <= 0x06F9) return 0x30 + (rune - 0x06F0);
    return null;
  }

  /// Harakat, Quranic annotation marks, tatweel and invisible joiners.
  static bool _isIgnoredMark(int rune) {
    return (rune >= 0x0610 && rune <= 0x061A) ||
        (rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0670 ||
        rune == 0x0640 ||
        (rune >= 0x06D6 && rune <= 0x06ED) ||
        rune == 0x200B ||
        rune == 0x200C ||
        rune == 0x200D ||
        rune == 0x200E ||
        rune == 0x200F ||
        rune == 0xFEFF;
  }

  /// Alef/ya/ta variants folded to one form each, else null.
  static int? _foldLetter(int rune) => switch (rune) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // أ إ آ ٱ → ا
        0x0649 => 0x064A, // ى → ي
        0x0626 => 0x064A, // ئ → ي
        0x0629 => 0x0647, // ة → ه
        0x0624 => 0x0648, // ؤ → و
        _ => null,
      };

  /// Letters and digits that survive normalisation.
  static bool _isContentRune(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return true;
    if (rune >= 0x41 && rune <= 0x5A) return true;
    if (rune >= 0x61 && rune <= 0x7A) return true;
    if (rune >= 0x0621 && rune <= 0x063A) return true;
    if (rune >= 0x0641 && rune <= 0x064A) return true;
    if (rune >= 0x0671 && rune <= 0x06D3) return true;
    if (rune >= 0x06FA && rune <= 0x06FF) return true;
    return false;
  }
}
