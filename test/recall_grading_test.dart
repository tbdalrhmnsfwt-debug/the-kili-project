import 'package:flutter_test/flutter_test.dart';

import '../lib/models/recall.dart';

RecallCard _card({
  int reviews = 0,
  int correctReviews = 0,
  DateTime? dueAt,
}) => RecallCard(
  id: 'card-1',
  kind: CardKind.multipleChoice,
  front: const CardFace(text: 'ما هو ناتج ٢ + ٣؟'),
  back: const CardFace(text: '٥'),
  lessonId: 'lesson-1',
  reviews: reviews,
  correctReviews: correctReviews,
  dueAt: dueAt,
  sourcePage: 12,
  sourceSectionId: 's1',
  sourceBookTitle: 'الرياضيات',
);

void main() {
  final now = DateTime(2026, 10, 24, 18);

  group('ReviewGrade → next due date', () {
    test('knew follows the 1, 3, 7, 14, 30-day ladder', () {
      expect(_card().graded(ReviewGrade.knew, now: now).dueAt,
          DateTime(2026, 10, 25, 18));
      expect(_card(reviews: 1, correctReviews: 1)
          .graded(ReviewGrade.knew, now: now).dueAt, DateTime(2026, 10, 27, 18));
      expect(_card(reviews: 2, correctReviews: 2)
          .graded(ReviewGrade.knew, now: now).dueAt, DateTime(2026, 10, 31, 18));
      expect(_card(reviews: 3, correctReviews: 3)
          .graded(ReviewGrade.knew, now: now).dueAt, DateTime(2026, 11, 7, 18));
      expect(_card(reviews: 4, correctReviews: 4)
          .graded(ReviewGrade.knew, now: now).dueAt, DateTime(2026, 11, 23, 18));
      // Beyond the ladder stays at 30 days rather than growing forever.
      expect(_card(reviews: 9, correctReviews: 9)
          .graded(ReviewGrade.knew, now: now).dueAt, DateTime(2026, 11, 23, 18));
    });

    test('difficult keeps the streak and repeats tomorrow', () {
      final graded = _card(reviews: 3, correctReviews: 2)
          .graded(ReviewGrade.difficult, now: now);
      expect(graded.dueAt, DateTime(2026, 10, 25, 18));
      expect(graded.correctReviews, 2);
    });

    test('again resets the streak and returns in ten minutes', () {
      final graded = _card(reviews: 5, correctReviews: 5)
          .graded(ReviewGrade.again, now: now);
      expect(graded.dueAt, DateTime(2026, 10, 24, 18, 10));
      expect(graded.correctReviews, 0);
    });

    test('every grade records an attempt and keeps provenance', () {
      for (final grade in ReviewGrade.values) {
        final graded = _card(reviews: 2, correctReviews: 1)
            .graded(grade, now: now);
        expect(graded.reviews, 3, reason: 'grade $grade');
        expect(graded.sourcePage, 12);
        expect(graded.sourceSectionId, 's1');
        expect(graded.sourceBookTitle, 'الرياضيات');
      }
    });

    test('reviewed keeps its original two-way behaviour', () {
      expect(_card().reviewed(wasCorrect: true, now: now).dueAt,
          DateTime(2026, 10, 25, 18));
      expect(_card().reviewed(wasCorrect: false, now: now).dueAt,
          DateTime(2026, 10, 24, 18, 10));
    });

    test('grading round-trips through JSON without losing the grade state',
        () {
      final graded = _card().graded(ReviewGrade.knew, now: now);
      final restored = RecallCard.fromJson(graded.toJson());
      expect(restored.correctReviews, 1);
      expect(restored.reviews, 1);
      expect(restored.dueAt, graded.dueAt);
      expect(restored.sourcePage, 12);
    });
  });

  group('ReviewQueue', () {
    test('due() only returns cards whose time has come, oldest first', () {
      final queue = ReviewQueue(
        cards: [
          _card(dueAt: DateTime(2026, 10, 25)),
          _card(dueAt: DateTime(2026, 10, 23)),
          _card(dueAt: null),
        ],
      );

      final due = queue.due(now);
      expect(due, hasLength(2));
      expect(due.first.dueAt, DateTime(2026, 10, 23));
      expect(due.last.dueAt, isNull);
    });

    test('addAll skips empty and duplicate ids', () {
      final queue = ReviewQueue(cards: [_card()]);
      final added = queue.addAll([
        _card(),
        const RecallCard(
          id: '',
          kind: CardKind.swipe,
          front: CardFace(text: 'بلا معرف'),
          lessonId: 'x',
        ),
        const RecallCard(
          id: 'card-2',
          kind: CardKind.trueFalse,
          front: CardFace(text: 'صح؟'),
          lessonId: 'x',
        ),
      ]);
      expect(added, 1);
      expect(queue.total, 2);
    });

    test('accuracy ignores never-reviewed cards', () {
      final queue = ReviewQueue(
        cards: [
          _card(reviews: 2, correctReviews: 1),
          _card(reviews: 2, correctReviews: 2),
          _card(),
        ],
      );
      expect(queue.accuracy, closeTo(0.75, 0.001));
    });

    test('forSection only returns cards linked to that section', () {
      final queue = ReviewQueue(
        cards: [
          _card(),
          const RecallCard(
            id: 'other',
            kind: CardKind.swipe,
            front: CardFace(text: 'س'),
            lessonId: 'x',
            sourceSectionId: 's2',
          ),
        ],
      );
      expect(queue.forSection('s1'), hasLength(1));
      expect(queue.forSection('missing'), isEmpty);
    });
  });
}
