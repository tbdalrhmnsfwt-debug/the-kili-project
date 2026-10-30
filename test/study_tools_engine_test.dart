import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/evidence_validator.dart';
import 'package:zaker_ai/core/batches/study_tools_engine.dart';
import 'package:zaker_ai/models/study_source.dart';

const _kineticLine = 'الطاقة الحركية: طاقة يمتلكها الجسم بسبب حركته.';
const _massLine = 'الكتلة: مقدار ما يحتويه الجسم من مادة.';
const _speedLine = 'السرعة: المسافة التي يقطعها الجسم في وحدة الزمن.';
const _forceLine = 'القوة: مؤثر يغير من حالة حركة الجسم أو شكله.';

const _kineticDefinition = 'طاقة يمتلكها الجسم بسبب حركته.';
const _massDefinition = 'مقدار ما يحتويه الجسم من مادة.';
const _speedDefinition = 'المسافة التي يقطعها الجسم في وحدة الزمن.';

SourceDocument _document() => SourceDocument(
      resourceId: 'res-phy',
      batchId: 'batch-1',
      title: 'ملزمة الفيزياء',
      sha256: 'sha-phy',
      pages: const [
        SourcePage(
          pageNumber: 1,
          text: '''
الوحدة الأولى: الحركة

$_kineticLine
$_massLine
$_speedLine
''',
        ),
        SourcePage(
          pageNumber: 2,
          text: '''
الوحدة الثانية: القوى

$_forceLine
وفي سنة ١٩٤٨ تم الإعلان عن وحدة القياس الجديدة.
تبلغ سرعة الصوت ٣٤٣ متر في الثانية.
الخطوة الأولى: نحدد الكتلة والسرعة.
الخطوة الثانية: نحسب الطاقة الحركية من المعادلة.
''',
        ),
        SourcePage(pageNumber: 3, text: ''),
      ],
      warnings: const [],
      extractedAt: DateTime.utc(2026, 10, 25),
      pageCount: 3,
    );

StudyQuestion _validQuestion() => const StudyQuestion(
      id: 'q-valid',
      kind: StudyQuestionKind.multipleChoice,
      prompt: 'إيه التعريف الصح لـ «الكتلة»؟',
      choices: [_massDefinition, _kineticDefinition, _speedDefinition],
      correctIndex: 0,
      page: 1,
      evidence: _massLine,
      explanation: 'النص في صفحة 1.',
    );

StudyQuestion _copyWith({
  String? prompt,
  List<String>? choices,
  int? correctIndex,
  int? page,
  String? evidence,
  StudyQuestionKind? kind,
}) {
  final base = _validQuestion();
  return StudyQuestion(
    id: base.id,
    kind: kind ?? base.kind,
    prompt: prompt ?? base.prompt,
    choices: choices ?? base.choices,
    correctIndex: correctIndex ?? base.correctIndex,
    page: page ?? base.page,
    evidence: evidence ?? base.evidence,
    explanation: base.explanation,
  );
}

void main() {
  const engine = StudyToolsEngine();

  group('test generation', () {
    final document = _document();

    test('builds questions that all pass validation', () {
      final questions = engine.test(document);

      expect(questions, isNotEmpty);
      for (final question in questions) {
        expect(
          engine.validate(question, document).rejection,
          StudyRejection.none,
          reason: question.prompt,
        );
        expect(question.evidence, isNotEmpty);
        expect(document.page(question.page), isNotNull);
      }
      expect(
        questions.any(
          (question) => question.kind == StudyQuestionKind.multipleChoice,
        ),
        isTrue,
      );
      expect(
        questions.any((question) => question.kind == StudyQuestionKind.cloze),
        isTrue,
      );
    });

    test('is deterministic for the same document', () {
      final first = engine.test(document);
      final second = engine.test(document);

      expect(
        second.map((question) => question.id),
        first.map((question) => question.id),
      );
      expect(
        second.map((question) => question.correctIndex),
        first.map((question) => question.correctIndex),
      );
    });

    test('respects the requested limit', () {
      expect(engine.test(document, limit: 2).length, lessThanOrEqualTo(2));
      expect(engine.test(document).length, lessThanOrEqualTo(10));
    });

    test('a document with no text produces no questions', () {
      final empty = SourceDocument(
        resourceId: 'res-empty',
        batchId: 'batch-1',
        title: 'ملف فاضي',
        sha256: 'sha-empty',
        pages: const [SourcePage(pageNumber: 1, text: '')],
        warnings: const [],
        extractedAt: DateTime.utc(2026, 10, 25),
      );

      expect(engine.test(empty), isEmpty);
    });
  });

  group('question validation', () {
    final document = _document();

    test('accepts a well-formed grounded question', () {
      expect(engine.validate(_validQuestion(), document).isValid, isTrue);
    });

    test('rejects fewer than three choices', () {
      final question = _copyWith(
        choices: const [_massDefinition, _kineticDefinition],
      );

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.tooFewChoices,
      );
    });

    test('rejects duplicate choices', () {
      final question = _copyWith(
        choices: const [_massDefinition, _massDefinition, _speedDefinition],
      );

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.duplicateChoices,
      );
    });

    test('rejects a missing correct index', () {
      final question = _copyWith(correctIndex: 9);

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.invalidCorrectIndex,
      );
    });

    test('rejects an answer the source does not contain', () {
      final question = _copyWith(
        choices: const [
          'طاقة الوضع لجسم مرتفع عن سطح الأرض.',
          _kineticDefinition,
          _speedDefinition,
        ],
      );

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.answerNotInSource,
      );
    });

    test('rejects a truncated stem', () {
      final question = _copyWith(prompt: 'إيه التعريف الصح لـ الكتلة من');

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.truncatedStem,
      );
    });

    test('rejects a stem shorter than a question', () {
      final question = _copyWith(prompt: 'ليه؟');

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.shortPrompt,
      );
    });

    test('rejects a prompt that gives the answer away', () {
      final question = _copyWith(
        prompt: 'إيه التعريف الصح لـ مقدار ما يحتويه الجسم من مادة؟',
      );

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.answerInStem,
      );
    });

    test('rejects evidence that is not on the cited page', () {
      final question = _copyWith(page: 2);

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.evidenceMissing,
      );
    });

    test('rejects a citation to a page outside the document', () {
      final question = _copyWith(page: 99);

      expect(
        engine.validate(question, document).rejection,
        StudyRejection.evidenceMissing,
      );
    });

    test('accepts a true/false question whose answer is a judgement', () {
      const question = StudyQuestion(
        id: 'q-tf',
        kind: StudyQuestionKind.trueFalse,
        prompt: 'صح أم خطأ: $_kineticLine',
        choices: ['صح', 'خطأ'],
        correctIndex: 0,
        page: 1,
        evidence: _kineticLine,
        explanation: '',
      );

      expect(engine.validate(question, document).isValid, isTrue);
    });
  });

  group('information bank', () {
    final document = _document();
    final bank = engine.bank(document);

    test('extracts definitions, dates, numbers and steps', () {
      final kinds = bank.facts.map((fact) => fact.kind).toSet();

      expect(kinds, contains(StudyFactKind.definition));
      expect(kinds, contains(StudyFactKind.date));
      expect(kinds, contains(StudyFactKind.number));
      expect(kinds, contains(StudyFactKind.step));
    });

    test('every fact is grounded on the page it names', () {
      for (final fact in bank.facts) {
        expect(
          EvidenceValidator.verify(
            document,
            page: fact.page,
            excerpt: fact.excerpt,
          ).isFound,
          isTrue,
          reason: '${fact.kind.name}: ${fact.text}',
        );
      }
    });

    test('search finds a fact through folded Arabic', () {
      final hits = bank.matching(EvidenceValidator.normalize, 'الطاقه');

      expect(hits, isNotEmpty);
      expect(
        hits.any(
          (fact) =>
              fact.kind == StudyFactKind.definition &&
              fact.term == 'الطاقة الحركية',
        ),
        isTrue,
      );
    });

    test('a document with no text has an empty bank', () {
      final empty = SourceDocument(
        resourceId: 'res-empty',
        batchId: 'batch-1',
        title: 'ملف فاضي',
        sha256: 'sha-empty',
        pages: const [SourcePage(pageNumber: 1, text: '')],
        warnings: const [],
        extractedAt: DateTime.utc(2026, 10, 25),
      );

      expect(engine.bank(empty).isEmpty, isTrue);
    });
  });

  group('mind map', () {
    final document = _document();

    test('uses printed unit headings as the top level', () {
      final map = engine.mindMap(document);

      expect(map.title, 'ملزمة الفيزياء');
      expect(map.root.children.first.label, 'الوحدة الأولى: الحركة');
      expect(map.root.children.first.page, 1);
      expect(
        map.root.children.any(
          (node) => node.label == 'الوحدة الثانية: القوى' && node.page == 2,
        ),
        isTrue,
      );
    });

    test('every page reference exists in the document', () {
      final map = engine.mindMap(document);

      void walk(StudyMapNode node) {
        if (node.page != null) {
          expect(document.page(node.page!), isNotNull, reason: node.label);
        }
        for (final child in node.children) {
          walk(child);
        }
      }

      walk(map.root);
    });

    test('the outline is the accessible alternative', () {
      final outline = engine.mindMap(document).outline;

      expect(outline.first, 'ملزمة الفيزياء');
      expect(
        outline.any((line) =>
            line.contains('الوحدة الأولى') && line.contains('صفحة 1')),
        isTrue,
      );
    });

    test('a document with no text says so instead of inventing a map', () {
      final empty = SourceDocument(
        resourceId: 'res-empty',
        batchId: 'batch-1',
        title: 'ملف فاضي',
        sha256: 'sha-empty',
        pages: const [SourcePage(pageNumber: 1, text: '')],
        warnings: const [],
        extractedAt: DateTime.utc(2026, 10, 25),
      );
      final map = engine.mindMap(empty);

      expect(map.root.children.single.label, 'مفيش نص كفاية لبناء خريطة');
      expect(map.root.children.single.page, isNull);
      expect(map.root.note, 'مفيش نص مقروء في الملف');
    });
  });
}
