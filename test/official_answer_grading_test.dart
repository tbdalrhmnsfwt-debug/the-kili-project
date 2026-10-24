import 'package:flutter_test/flutter_test.dart';

import '../lib/core/answer_grading.dart';
import '../lib/models/exam.dart';

ExamQuestion _question(String modelAnswer) => ExamQuestion(
  id: 'q1',
  prompt: 'اشرح مفهوم المتجه.',
  answerKind: AnswerKind.freeText,
  modelAnswer: modelAnswer,
);

void main() {
  group('choice answer validation', () {
    ExamQuestion choice({int? index, List<String> options = const ['أ', 'ب']}) =>
        ExamQuestion(
          id: 'q',
          prompt: 'اختر',
          answerKind: AnswerKind.multipleChoice,
          options: options,
          correctIndex: index,
        );

    test('accepts an index that exists', () {
      expect(hasValidChoiceAnswer(choice(index: 0)), isTrue);
      expect(isChoiceAnswerCorrect(choice(index: 1), 1), isTrue);
      expect(isChoiceAnswerCorrect(choice(index: 1), 0), isFalse);
    });

    test('rejects a missing, negative or out-of-range index', () {
      expect(hasValidChoiceAnswer(choice()), isFalse);
      expect(hasValidChoiceAnswer(choice(index: -1)), isFalse);
      expect(hasValidChoiceAnswer(choice(index: 2)), isFalse);
      expect(hasValidChoiceAnswer(choice(index: 0, options: [])), isFalse);
      expect(isChoiceAnswerCorrect(choice(index: 5), 0), isFalse);
    });
  });

  group('gradeShortAnswer', () {
    test('accepts an answer that contains the model answer', () {
      expect(
        gradeShortAnswer(
          'المتجه كمية لها مقدار واتجاه',
          _question('المتجه كمية لها مقدار واتجاه'),
        ),
        isTrue,
      );
    });

    test('accepts a paraphrased answer with enough keyword overlap', () {
      expect(
        gradeShortAnswer(
          'المتجه له مقدار واتجاه ويستخدم في الفيزياء',
          _question('المتجه كمية لها مقدار واتجاه'),
        ),
        isTrue,
      );
    });

    test('rejects an unrelated answer', () {
      expect(
        gradeShortAnswer(
          'الماء يغلي عند مئة درجة',
          _question('المتجه كمية لها مقدار واتجاه'),
        ),
        isFalse,
      );
    });

    test('rejects an empty answer even with an empty model answer', () {
      expect(gradeShortAnswer('   ', _question('')), isFalse);
    });

    test('normalises diacritics before comparing', () {
      expect(
        gradeShortAnswer(
          'الكمية لها مقدار واتجاه',
          _question('الْكَمِّيَّة لَهَا مِقْدَار وَاتِّجَاه'),
        ),
        isTrue,
      );
    });

    test('an empty model answer needs a substantive answer', () {
      expect(gradeShortAnswer('قصير', _question('')), isFalse);
      expect(gradeShortAnswer('إجابة واضحة ومكتملة', _question('')), isTrue);
    });

    test('a model answer of only short words falls back to length', () {
      expect(gradeShortAnswer('لا', _question('من في')), isFalse);
      expect(gradeShortAnswer('إجابة طويلة كفاية', _question('من في')), isTrue);
    });

    test('does not accept a one-word fragment of a long model answer', () {
      expect(
        gradeShortAnswer(
          'المتجه',
          _question('المتجه كمية رياضية لها مقدار واتجاه ويمثل بسهم'),
        ),
        isFalse,
      );
    });
  });
}
