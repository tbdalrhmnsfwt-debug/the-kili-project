import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/home_light_style.dart';

/// Every tinted field the dashboard paints text on.
const Map<String, List<Color>> _fields = {
  'mint': HomeLight.mintGradient,
  'cyan': HomeLight.cyanGradient,
  'orange': HomeLight.orangeGradient,
  'purple': HomeLight.purpleGradient,
  'deep blue': HomeLight.deepBlueGradient,
  'teal': HomeLight.tealGradient,
  'assistant': HomeLight.assistantGradient,
  'bag': HomeLight.bagGradient,
  'tasks': HomeLight.tasksGradient,
  'header': HomeLight.headerGradient,
  'countdown': HomeLight.countdownGradient,
  'advice': HomeLight.adviceGradient,
};

void main() {
  test('supporting copy clears 4.5:1 on every dashboard field', () {
    for (final entry in _fields.entries) {
      for (final stop in entry.value) {
        expect(
          contrastRatio(HomeLight.mutedStrong, stop),
          greaterThanOrEqualTo(4.5),
          reason: 'mutedStrong on ${entry.key} $stop',
        );
      }
    }
    for (final page in <Color>[HomeLight.page, HomeLight.pageAlt]) {
      expect(
        contrastRatio(HomeLight.mutedStrong, page),
        greaterThanOrEqualTo(4.5),
        reason: 'mutedStrong on page $page',
      );
    }
    // The brief's secondary grey is only used on pure white, where it passes.
    expect(contrastRatio(HomeLight.muted, Colors.white),
        greaterThanOrEqualTo(4.5));
  });

  test('countdown and advice accents keep their text readable', () {
    for (final stop in HomeLight.countdownGradient) {
      expect(
        contrastRatio(HomeLight.orangeDeep, stop),
        greaterThanOrEqualTo(4.5),
        reason: 'countdown number on $stop',
      );
    }
    for (final stop in HomeLight.adviceGradient) {
      expect(
        contrastRatio(HomeLight.mintDeep, stop),
        greaterThanOrEqualTo(4.5),
        reason: 'advice heading on $stop',
      );
    }
  });
}
