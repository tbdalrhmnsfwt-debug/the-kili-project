import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every line under `lib/` that matches [pattern], as `path:line text`.
List<String> _matches(RegExp pattern) {
  final hits = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        hits.add('${entity.path}:${i + 1} ${lines[i].trim()}');
      }
    }
  }
  return hits;
}

void main() {
  test('no hero panel paints the palette primary behind fixed white content', () {
    // `colorScheme.primary` is gold in dark, black_gold and deep_blue. Panels
    // built from it mix in the constant navy-light tone and keep hand-written
    // `Colors.white` labels, so the fill has to stay navy in every appearance.
    final offenders = _matches(
      RegExp(r'theme\.colorScheme\.primary,\s*ZakerColors\.primaryLight'),
    );
    expect(offenders, isEmpty);
  });

  test('the constant navy-light tone is never used as a foreground', () {
    // On a dark surface `#1B2B4A` is unreadable; foregrounds come from the
    // palette roles (`onSurface`, `onPrimary`, `primary`) instead.
    final offenders = _matches(
      RegExp(r'color:\s*ZakerColors\.primaryLight\b|\?\s*ZakerColors\.primaryLight\b'),
    );
    expect(offenders, isEmpty);
  });
}
