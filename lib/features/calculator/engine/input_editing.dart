/// Pure text-editing helpers for the calculator input.
///
/// The UI keeps a raw expression and a caret position; these functions change
/// that pair without evaluating or normalising the source. Keeping them here
/// makes the ± behaviour testable without Flutter.
library;

/// Toggles the sign of the numeric literal at the caret.
///
/// If the caret follows an operator or an opening parenthesis, a unary minus
/// is inserted for the operand about to be typed. Otherwise the last numeric
/// literal before the caret is negated, and a directly attached unary minus is
/// removed when one is present. Binary subtraction (`2−3`) is never mistaken
/// for a unary sign.
({String source, int cursor}) toggleSignAt(String source, int cursor) {
  final position = cursor.clamp(0, source.length);
  final prefix = source.substring(0, position);
  final trimmed = prefix.trimRight();

  // A trailing unary minus (after an operator, an opening parenthesis, or at
  // the start) is the one this key just inserted, so pressing it again removes
  // it instead of stacking a second sign.
  if (trimmed.isNotEmpty && _isMinus(trimmed[trimmed.length - 1])) {
    final minusAt = trimmed.length - 1;
    final before = minusAt - 1;
    if (before < 0 || _isOperator(trimmed[before])) {
      return (
        source: source.substring(0, minusAt) + source.substring(minusAt + 1),
        cursor: minusAt,
      );
    }
  }

  if (trimmed.isEmpty || _isOperator(trimmed[trimmed.length - 1])) {
    return (
      source: '${prefix}−${source.substring(position)}',
      cursor: position + 1,
    );
  }

  final matches = _numberPattern.allMatches(prefix).toList(growable: false);
  if (matches.isEmpty) {
    return (
      source: '${prefix}−${source.substring(position)}',
      cursor: position + 1,
    );
  }
  final start = matches.last.start;
  if (start > 0 && _isMinus(source[start - 1])) {
    final before = start - 2;
    final attachedUnary = before < 0 ||
        _isOperator(source[before]) ||
        source[before].trim().isEmpty;
    if (attachedUnary) {
      return (
        source: source.substring(0, start - 1) + source.substring(start),
        cursor: (position - 1).clamp(0, source.length - 1),
      );
    }
  }
  return (
    source: source.substring(0, start) +
        '−' +
        source.substring(start),
    cursor: position + 1,
  );
}

final RegExp _numberPattern = RegExp(
  r'(\d+(?:\.\d*)?|\.\d+)(?:[eE][+\-−]?\d+)?',
);

bool _isMinus(String char) => char == '−' || char == '-';

bool _isOperator(String char) {
  return const <String>{
    '+',
    '−',
    '-',
    '×',
    '÷',
    '*',
    '/',
    '^',
    '(',
    ',',
    '،',
  }.contains(char);
}
