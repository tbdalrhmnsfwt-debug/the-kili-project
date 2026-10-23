/// Builds active-recall cards from the bundled textbook library.
///
/// Each card is a fill-in-the-blank sentence taken from a readable book, with
/// the missing word on the back. This gives the recall queue real, book
/// specific material on a fresh install instead of an empty screen.
library;

import '../models/manhaji.dart';
import '../models/recall.dart';
import 'asset_service.dart';
import 'quiz_generator.dart';

/// Scans [grades] and returns up to [maxCards] recall cards.
///
/// At most [maxBooks] payloads are opened; encrypted or empty books are
/// skipped by [AssetService].
Future<List<RecallCard>> buildRecallCards({
  required AssetService service,
  required List<Grade> grades,
  int maxCards = 40,
  int maxBooks = 16,
}) async {
  final cards = <RecallCard>[];
  final now = DateTime.now();
  var scanned = 0;

  outer:
  for (final grade in grades) {
    for (final book in grade.books) {
      if (cards.length >= maxCards || scanned >= maxBooks) break outer;
      scanned++;
      try {
        final json = await service.loadBook(book);
        final lessons = service.parseLessons(json);
        final questions = generateClozeQuestions(
          book: book,
          lessons: lessons,
          maxQuestions: 10,
        );
        for (final question in questions) {
          final correct = question.correctIndex;
          if (correct == null || correct >= question.options.length) continue;
          cards.add(
            RecallCard(
              id: 'rc-${question.id}',
              kind: CardKind.fillBlank,
              front: CardFace(text: question.prompt),
              back: CardFace(
                text: question.options[correct],
                hint: question.explanation,
              ),
              lessonId: '${book.id}-${question.lessonNumber ?? 0}',
              bookId: book.id,
              lessonNumber: question.lessonNumber,
              createdAt: now,
            ),
          );
          if (cards.length >= maxCards) break;
        }
      } catch (_) {
        // Encrypted or unreadable book — move on to the next one.
      }
    }
  }

  return cards;
}
