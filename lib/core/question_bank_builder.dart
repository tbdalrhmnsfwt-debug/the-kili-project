/// Builds saved question banks from the bundled textbook library.
///
/// The original app generates a bank per lesson. The replica derives cloze
/// questions on-device from every readable book (the ones that ship a
/// plaintext lesson document), so both the question bank screen and the games
/// have real, book-specific questions without any network round-trip.
library;

import '../models/exam.dart';
import '../models/manhaji.dart';
import 'asset_service.dart';
import 'quiz_generator.dart';

/// Scans [grades] and returns up to [maxBanks] banks of at least four
/// questions each.
///
/// At most [maxBooks] payloads are opened; encrypted or empty books are
/// skipped cheaply by [AssetService].
Future<List<QuestionBank>> buildQuestionBanks({
  required AssetService service,
  required List<Grade> grades,
  int maxBanks = 4,
  int maxBooks = 24,
}) async {
  final banks = <QuestionBank>[];
  var scanned = 0;

  for (final grade in grades) {
    for (final book in grade.books) {
      if (banks.length >= maxBanks || scanned >= maxBooks) break;
      scanned++;
      try {
        final json = await service.loadBook(book);
        final lessons = service.parseLessons(json);
        final questions = generateClozeQuestions(
          book: book,
          lessons: lessons,
          maxQuestions: 12,
        );
        if (questions.length < 4) continue;
        banks.add(
          QuestionBank(
            id: 'bank-${book.id}',
            title: 'بنك ${book.title}',
            subject: book.subject,
            bookId: book.id,
            questions: questions,
          ),
        );
      } catch (_) {
        // Encrypted or unreadable book — move on to the next one.
      }
    }
    if (banks.length >= maxBanks || scanned >= maxBooks) break;
  }

  return banks;
}
