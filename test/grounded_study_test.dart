import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/ai_service.dart';
import 'package:zaker_ai/core/grounded_study.dart';
import 'package:zaker_ai/models/extraction.dart';
import 'package:zaker_ai/models/official_book.dart';

/// The assistant, with the grounded call replaced by a fixed reply.
class _FakeAi extends AiService {
  _FakeAi(this.reply);

  final String? reply;
  int groundedCalls = 0;

  @override
  Future<String?> askGrounded({
    required String question,
    required String context,
    String? subject,
    int? pageStart,
    int? pageEnd,
  }) async {
    groundedCalls++;
    return reply;
  }
}

OfficialPassage _passage() {
  final page = ExtractedPage(
    pageNumber: 12,
    text: 'الخلية هي وحدة بناء الكائن الحي. تتكون الخلية من غشاء بلازمي '
        'وسيتوبلازم ونواة تحتوي على المادة الوراثية.',
  );
  final section = ExtractedSection(
    id: 's1',
    title: 'الخلية',
    startPage: 12,
    endPage: 12,
    text: page.text,
  );
  return OfficialPassage(
    book: const OfficialBook(
      id: 'bio-sec1',
      grade: 'sec1',
      subject: 'الأحياء',
      titleAr: 'الأحياء — الصف الأول الثانوي',
      system: EducationSystem.generalSecondary,
    ),
    section: section,
    extraction: ExtractedBook(
      bookId: 'bio-sec1',
      sha256: 'abc',
      extractedAt: DateTime(2026, 10, 1),
      pages: [page],
      sections: [section],
      textPageCount: 1,
      ocrPageCount: 0,
      warnings: const [],
      status: BookExtractionStatus.ready,
    ),
  );
}

void main() {
  group('GroundedStudyService.explanation', () {
    test('without a service the local explanation is returned', () async {
      final note = await GroundedStudyService().explanation(_passage());

      expect(note.isAi, isFalse);
      expect(note.label, 'شرح محلي من الكتاب');
      expect(note.body, contains('الخلية'));
    });

    test('a null grounded answer falls back to the local note', () async {
      final ai = _FakeAi(null);

      final note = await GroundedStudyService(ai: ai).explanation(_passage());

      expect(ai.groundedCalls, 1);
      expect(note.isAi, isFalse);
      expect(note.body, contains('الخلية'));
    });

    test('a grounded answer is used and labelled as AI', () async {
      final ai = _FakeAi('الخلية هي وحدة البناء [صفحة 12].');

      final note = await GroundedStudyService(ai: ai).explanation(_passage());

      expect(ai.groundedCalls, 1);
      expect(note.isAi, isTrue);
      expect(note.label, 'شرح مساعد بالذكاء الاصطناعي');
      expect(note.body, 'الخلية هي وحدة البناء [صفحة 12].');
      expect(note.warning, contains('الذكاء الاصطناعي'));
    });
  });
}
