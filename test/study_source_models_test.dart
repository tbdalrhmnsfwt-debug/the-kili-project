import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/models/study_source.dart';

Map<String, dynamic> _roundTrip(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('SourceDocument', () {
    final document = SourceDocument(
      resourceId: 'res-1',
      batchId: 'batch-1',
      title: 'ملزمة الرياضيات',
      sha256: 'sha-b',
      pages: const [
        SourcePage(
          pageNumber: 1,
          text: 'الطاقة الحركية للجسم تساوي نصف الكتلة مضروبة في مربع السرعة.',
        ),
        SourcePage(pageNumber: 2, text: 'صفحة مصورة'),
        SourcePage(pageNumber: 3, text: '', fromOcr: true),
      ],
      warnings: const ['اتخطينا OCR لصفحة واحدة.'],
      extractedAt: DateTime.utc(2026, 10, 25, 9, 30),
      pageCount: 3,
      ocrPageCount: 1,
    );

    test('round-trips through JSON without losing OCR flags or warnings', () {
      final restored = SourceDocument.fromJson(_roundTrip(document.toJson()));

      expect(restored.resourceId, 'res-1');
      expect(restored.batchId, 'batch-1');
      expect(restored.title, 'ملزمة الرياضيات');
      expect(restored.sha256, 'sha-b');
      expect(restored.pages.length, 3);
      expect(restored.pages[2].fromOcr, isTrue);
      expect(restored.warnings, ['اتخطينا OCR لصفحة واحدة.']);
      expect(restored.pageCount, 3);
      expect(restored.ocrPageCount, 1);
      expect(restored.extractedAt, DateTime.utc(2026, 10, 25, 9, 30));
    });

    test('counts only pages with enough text as usable', () {
      expect(document.usablePageCount, 1);
      expect(document.hasUsableText, isTrue);
      expect(document.pageText(2), 'صفحة مصورة');
      expect(document.pageText(99), '');
    });

    test('fromJson tolerates unknown and missing fields', () {
      final restored = SourceDocument.fromJson({
        'resource_id': 'res-2',
        'pages': [
          {'page': 1, 'text': 'نص'},
          'not-a-map',
        ],
      });

      expect(restored.resourceId, 'res-2');
      expect(restored.pages.length, 1);
      expect(restored.warnings, isEmpty);
    });
  });

  group('StudyQuestion', () {
    test('round-trips and exposes the correct choice', () {
      const question = StudyQuestion(
        id: 'q1',
        kind: StudyQuestionKind.cloze,
        prompt: 'الطاقة الحركية تساوي نصف الكتلة مضروبة في ________.',
        choices: ['مربع السرعة', 'الوزن', 'الحجم'],
        correctIndex: 0,
        page: 4,
        evidence:
            'الطاقة الحركية للجسم تساوي نصف الكتلة مضروبة في مربع السرعة.',
        explanation: 'النص في صفحة 4.',
      );
      final restored = StudyQuestion.fromJson(_roundTrip(question.toJson()));

      expect(restored.kind, StudyQuestionKind.cloze);
      expect(restored.correctChoice, 'مربع السرعة');
      expect(restored.page, 4);
      expect(restored.evidence, question.evidence);
    });

    test('an invalid index yields no correct choice', () {
      const question = StudyQuestion(
        id: 'q2',
        kind: StudyQuestionKind.multipleChoice,
        prompt: 'سؤال',
        choices: ['أ', 'ب', 'ج'],
        correctIndex: 7,
        page: 1,
        evidence: 'نص',
        explanation: '',
      );

      expect(question.correctChoice, isEmpty);
    });
  });

  group('StudyAttempt', () {
    test('round-trips answers and score', () {
      final attempt = StudyAttempt(
        resourceId: 'res-1',
        answers: const {'q1': 0, 'q2': 2},
        correct: 1,
        total: 2,
        submittedAt: DateTime.utc(2026, 10, 25, 10),
      );
      final restored = StudyAttempt.fromJson(_roundTrip(attempt.toJson()));

      expect(restored.answers, {'q1': 0, 'q2': 2});
      expect(restored.correct, 1);
      expect(restored.total, 2);
      expect(restored.score, 0.5);
    });

    test('an empty attempt never divides by zero', () {
      final attempt = StudyAttempt(
        resourceId: 'res-1',
        answers: const {},
        correct: 0,
        total: 0,
        submittedAt: DateTime.utc(2026, 10, 25),
      );

      expect(attempt.score, 0);
    });
  });

  group('StudyBank', () {
    final bank = StudyBank(
      resourceId: 'res-1',
      facts: const [
        StudyFact(
          id: 'f1',
          kind: StudyFactKind.definition,
          term: 'الطاقة الحركية',
          text: 'طاقة يمتلكها الجسم بسبب حركته.',
          page: 4,
          excerpt: 'الطاقة الحركية هي طاقة يمتلكها الجسم بسبب حركته.',
        ),
        StudyFact(
          id: 'f2',
          kind: StudyFactKind.date,
          text: '١٩٤٨',
          page: 7,
          excerpt: 'وفي سنة ١٩٤٨ تم الإعلان.',
        ),
      ],
    );

    test('search matches normalized Arabic', () {
      final hits = bank.matching(
        (value) => value.replaceAll('ة', 'ه'),
        'الطاقه',
      );

      expect(hits.map((fact) => fact.id), ['f1']);
    });

    test('an empty query returns every fact', () {
      expect(bank.matching((value) => value, '').length, 2);
    });

    test('round-trips a fact', () {
      final restored =
          StudyFact.fromJson(_roundTrip(bank.facts.first.toJson()));

      expect(restored.kind, StudyFactKind.definition);
      expect(restored.term, 'الطاقة الحركية');
      expect(restored.page, 4);
    });
  });

  group('StudyMindMap', () {
    test('outline lists every node with its page', () {
      const map = StudyMindMap(
        resourceId: 'res-1',
        title: 'الطاقة',
        root: StudyMapNode(
          id: 'root',
          label: 'الطاقة',
          children: [
            StudyMapNode(
              id: 'unit',
              label: 'الوحدة الأولى',
              page: 4,
              children: [
                StudyMapNode(
                  id: 'term',
                  label: 'الطاقة الحركية',
                  page: 5,
                ),
              ],
            ),
          ],
        ),
      );

      expect(map.outline, [
        'الطاقة',
        '  الوحدة الأولى — صفحة 4',
        '    الطاقة الحركية — صفحة 5',
      ]);
    });
  });

  group('StudyJob', () {
    test('progress is bounded and active states are explicit', () {
      const job = StudyJob(
        id: 'job-1',
        resourceId: 'res-1',
        state: StudyJobState.processing,
        done: 4,
        total: 10,
      );

      expect(job.isActive, isTrue);
      expect(job.progress, 0.4);
      expect(
        job.copyWith(state: StudyJobState.completed).isActive,
        isFalse,
      );
      expect(
        const StudyJob(
          id: 'job-2',
          resourceId: 'res-1',
          state: StudyJobState.queued,
        ).progress,
        0,
      );
    });
  });
}
