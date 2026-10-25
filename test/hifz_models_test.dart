import 'package:flutter_test/flutter_test.dart';

import '../lib/features/hifz/hifz_models.dart';

HifzPart _part({
  String id = 'p1',
  int stage = 0,
  double bestScore = 0,
  DateTime? nextReviewAt,
  DateTime? createdAt,
}) {
  return HifzPart(
    id: id,
    surahNumber: 112,
    surahName: 'الإخلاص',
    startAyah: 1,
    endAyah: 4,
    hideMode: HifzHideMode.lastWords,
    createdAt: createdAt ?? DateTime(2026, 10, 20),
    stage: stage,
    bestScore: bestScore,
    nextReviewAt: nextReviewAt,
  );
}

HifzSessionResult _result(List<bool> marks) {
  return HifzSessionResult(
    marks: [
      for (var i = 0; i < marks.length; i++)
        HifzAyahMark(ayahNumber: i + 1, correct: marks[i]),
    ],
  );
}

void main() {
  group('review ladder', () {
    test('is 1, 3, 7 and 14 days', () {
      final from = DateTime(2026, 10, 24, 15, 30);
      expect(hifzNextReview(stage: 0, from: from), DateTime(2026, 10, 25));
      expect(hifzNextReview(stage: 1, from: from), DateTime(2026, 10, 27));
      expect(hifzNextReview(stage: 2, from: from), DateTime(2026, 10, 31));
      expect(hifzNextReview(stage: 3, from: from), DateTime(2026, 11, 7));
    });

    test('clamps beyond the last step to fourteen days', () {
      final from = DateTime(2026, 10, 24);
      expect(hifzNextReview(stage: 9, from: from), DateTime(2026, 11, 7));
    });
  });

  group('HifzSessionResult', () {
    test('scores marks and finds the longest correct run', () {
      final result = _result([true, true, false, true]);
      expect(result.total, 4);
      expect(result.correct, 3);
      expect(result.needsReview, 1);
      expect(result.score, closeTo(0.75, 1e-9));
      expect(result.bestStreak, 2);
      expect(result.perfect, isFalse);
    });

    test('an empty session is safe and not perfect-free of division', () {
      final result = _result(const []);
      expect(result.total, 0);
      expect(result.score, 0);
      expect(result.bestStreak, 0);
      expect(result.perfect, isTrue);
    });
  });

  group('hifzApplySession', () {
    test('a perfect session advances the stage and the next date', () {
      final part = _part(stage: 0);
      final next = hifzApplySession(
        part,
        _result([true, true, true, true]),
        now: DateTime(2026, 10, 24, 18),
      );
      expect(next.stage, 1);
      expect(next.nextReviewAt, DateTime(2026, 10, 27));
      expect(next.bestScore, 1);
      expect(next.reviewCount, 1);
    });

    test('one needs-review mark resets the stage to the first step', () {
      final part = _part(stage: 3);
      final next = hifzApplySession(
        part,
        _result([true, false, true, true]),
        now: DateTime(2026, 10, 24, 18),
      );
      expect(next.stage, 0);
      expect(next.nextReviewAt, DateTime(2026, 10, 25));
      expect(next.bestScore, closeTo(0.75, 1e-9));
    });

    test('a first session keeps the one-day review and records the score', () {
      final part = _part(stage: 0, nextReviewAt: DateTime(2026, 10, 21));
      final next = hifzApplySession(
        part,
        _result([true, true, true, true]),
        now: DateTime(2026, 10, 24, 18),
        firstSession: true,
      );
      expect(next.stage, 0);
      expect(next.nextReviewAt, DateTime(2026, 10, 25));
      expect(next.bestScore, 1);
      expect(next.reviewCount, 1);
    });

    test('keeps the best score across sessions', () {
      final part = _part(stage: 2, bestScore: 0.75);
      final next = hifzApplySession(
        part,
        _result([false, false, false, false]),
        now: DateTime(2026, 10, 24),
      );
      expect(next.bestScore, 0.75);
      expect(next.reviewCount, 1);
    });
  });

  group('HifzPart', () {
    test('counts its ayahs and compares due dates', () {
      final part = _part(nextReviewAt: DateTime(2026, 10, 25));
      expect(part.ayahCount, 4);
      expect(part.isDue(DateTime(2026, 10, 24)), isFalse);
      expect(part.isDue(DateTime(2026, 10, 25)), isTrue);
      expect(_part().isDue(DateTime(2026, 10, 25)), isFalse);
    });

    test('round-trips through JSON', () {
      final part = _part(stage: 2, nextReviewAt: DateTime(2026, 11, 1));
      final restored = HifzPart.fromJson(part.toJson());
      expect(restored.id, part.id);
      expect(restored.surahNumber, part.surahNumber);
      expect(restored.surahName, part.surahName);
      expect(restored.startAyah, part.startAyah);
      expect(restored.endAyah, part.endAyah);
      expect(restored.hideMode, part.hideMode);
      expect(restored.createdAt, part.createdAt);
      expect(restored.stage, part.stage);
      expect(restored.nextReviewAt, part.nextReviewAt);
    });
  });

  group('HifzState', () {
    test('adds, replaces and removes parts and finds the next due one', () {
      final now = DateTime(2026, 10, 24);
      var state = const HifzState();
      state = state.upsertPart(
        _part(id: 'a', nextReviewAt: DateTime(2026, 10, 27)),
      );
      state = state.upsertPart(
        _part(id: 'b', nextReviewAt: DateTime(2026, 10, 25)),
      );
      expect(state.parts.length, 2);
      // Neither part has come due yet, so there is nothing to review today.
      expect(state.nextDue(now), isNull);

      state = state.upsertPart(
        _part(id: 'a', nextReviewAt: DateTime(2026, 10, 24)),
      );
      expect(state.parts.length, 2);
      expect(state.nextDue(now)?.id, 'a');

      state = state.removePart('a');
      expect(state.parts.single.id, 'b');
      expect(state.dueCount(now), 0);

      final due = state.upsertPart(
        _part(id: 'c', nextReviewAt: DateTime(2026, 10, 20)),
      );
      expect(due.dueCount(now), 1);
    });

    test('tracks the daily streak across sessions', () {
      var state = const HifzState();
      state = state.upsertPart(_part(id: 'a'));
      state = state.recordSession(
        'a',
        _result([true]),
        now: DateTime(2026, 10, 24, 9),
      );
      expect(state.streakDays, 1);
      expect(state.lastSessionDay, '2026-10-24');

      state = state.recordSession(
        'a',
        _result([true]),
        now: DateTime(2026, 10, 25, 9),
      );
      expect(state.streakDays, 2);

      state = state.recordSession(
        'a',
        _result([true]),
        now: DateTime(2026, 10, 29, 9),
      );
      expect(state.streakDays, 1);

      state = state.recordSession(
        'a',
        _result([true]),
        now: DateTime(2026, 10, 29, 21),
      );
      expect(state.streakDays, 1);
    });

    test('round-trips through JSON and tolerates corrupt input', () {
      var state = const HifzState(remindersEnabled: true, reminderHour: 21);
      state = state.upsertPart(
        _part(id: 'a', nextReviewAt: DateTime(2026, 10, 25)),
      );
      final restored = HifzState.fromJson(state.toJson());
      expect(restored.parts.single.id, 'a');
      expect(restored.remindersEnabled, isTrue);
      expect(restored.reminderHour, 21);

      final empty = HifzState.fromJson(null);
      expect(empty.parts, isEmpty);
      expect(empty.reminderHour, HifzState.defaultReminderHour);
    });
  });

  group('hifzReminderTime', () {
    test('fires on the due day at the reminder hour', () {
      expect(
        hifzReminderTime(
          dueDates: [DateTime(2026, 10, 25)],
          hour: 20,
          minute: 0,
          now: DateTime(2026, 10, 24, 10),
        ),
        DateTime(2026, 10, 25, 20),
      );
    });

    test('an overdue part fires today, or tomorrow once the hour passed', () {
      expect(
        hifzReminderTime(
          dueDates: [DateTime(2026, 10, 20)],
          hour: 20,
          minute: 0,
          now: DateTime(2026, 10, 24, 10),
        ),
        DateTime(2026, 10, 24, 20),
      );
      expect(
        hifzReminderTime(
          dueDates: [DateTime(2026, 10, 20)],
          hour: 20,
          minute: 0,
          now: DateTime(2026, 10, 24, 21),
        ),
        DateTime(2026, 10, 25, 20),
      );
    });

    test('returns null when nothing is scheduled', () {
      expect(
        hifzReminderTime(
          dueDates: const [],
          hour: 20,
          minute: 0,
          now: DateTime(2026, 10, 24, 10),
        ),
        isNull,
      );
    });
  });
}
