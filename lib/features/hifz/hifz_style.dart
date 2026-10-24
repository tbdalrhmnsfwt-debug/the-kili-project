/// Labels and icons shared by the hifz screens.
library;

import 'package:flutter/material.dart';

import 'hifz_models.dart';

extension HifzHideModeUi on HifzHideMode {
  String get label => switch (this) {
    HifzHideMode.none => 'بدون إخفاء',
    HifzHideMode.lastWords => 'آخر الكلمات',
    HifzHideMode.alternateWords => 'كلمة وكلمة',
    HifzHideMode.wholeAyah => 'الآية كلها',
    HifzHideMode.randomWords => 'كلمات عشوائية',
  };

  String get hint => switch (this) {
    HifzHideMode.none => 'الآية ظاهرة بالكامل',
    HifzHideMode.lastWords => 'آخر كلمة أو أكتر مخفية',
    HifzHideMode.alternateWords => 'كل كلمة تانية مخفية',
    HifzHideMode.wholeAyah => 'الآية كلها مخفية لحد ما تكشفها',
    HifzHideMode.randomWords => 'كلمات عشوائية مخفية',
  };

  IconData get icon => switch (this) {
    HifzHideMode.none => Icons.visibility_rounded,
    HifzHideMode.lastWords => Icons.short_text_rounded,
    HifzHideMode.alternateWords => Icons.linear_scale_rounded,
    HifzHideMode.wholeAyah => Icons.blur_on_rounded,
    HifzHideMode.randomWords => Icons.shuffle_rounded,
  };
}

/// `الآيات 1–4`.
String hifzRangeLabel(HifzPart part) =>
    'الآيات ${part.startAyah}–${part.endAyah}';

/// How far along the review ladder [part] is.
String hifzStageLabel(HifzPart part) {
  if (part.reviewCount == 0) return 'لسه ما بدأتش المراجعة';
  return switch (part.stage) {
    0 => 'مراجعة أولى',
    1 => 'بعد مراجعة أولى',
    2 => 'بعد مراجعتين',
    3 => 'مراجعة دورية كل أسبوعين',
    _ => 'مراجعة دورية',
  };
}

/// When the next review falls, relative to [now].
String hifzDueLabel(HifzPart part, DateTime now) {
  final due = part.nextReviewAt;
  if (due == null) return 'مفيش موعد مراجعة';
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = dueDay.difference(today).inDays;
  if (days <= 0) return 'مراجعة مستنية دلوقتي';
  if (days == 1) return 'المراجعة بكرة';
  if (days == 2) return 'المراجعة بعد بكرة';
  return 'المراجعة بعد $days يوم';
}
