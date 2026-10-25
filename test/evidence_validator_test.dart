import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/evidence_validator.dart';
import 'package:zaker_ai/models/study_source.dart';

SourceDocument _document(List<SourcePage> pages) => SourceDocument(
      resourceId: 'res-1',
      batchId: 'batch-1',
      title: 'ملزمة الرياضيات',
      sha256: 'sha-abc',
      pages: pages,
      warnings: const [],
      extractedAt: DateTime.utc(2026, 10, 25),
      pageCount: pages.length,
    );

void main() {
  group('EvidenceValidator.normalize', () {
    test('removes diacritics and tatweel', () {
      expect(
        EvidenceValidator.normalize('الكِتَابُ'),
        EvidenceValidator.normalize('الكتاب'),
      );
      expect(EvidenceValidator.normalize('كـــتاب'), 'كتاب');
    });

    test('folds alef, ya and ta variants', () {
      expect(
        EvidenceValidator.normalize('إبراهيم'),
        EvidenceValidator.normalize('ابراهيم'),
      );
      expect(
        EvidenceValidator.normalize('مصطفى'),
        EvidenceValidator.normalize('مصطفي'),
      );
      expect(
        EvidenceValidator.normalize('مدرسة'),
        EvidenceValidator.normalize('مدرسه'),
      );
      expect(
        EvidenceValidator.normalize('مؤمن'),
        EvidenceValidator.normalize('مومن'),
      );
    });

    test('converts Arabic-Indic digits', () {
      expect(EvidenceValidator.normalize('سنة ١٩٤٨'), 'سنه 1948');
      expect(EvidenceValidator.normalize('سنة ۱۹۴۸'), 'سنه 1948');
    });

    test('collapses punctuation, newlines and extra spaces', () {
      expect(
        EvidenceValidator.normalize('الطاقة\n\n  =  الكتلة ×  السرعة.'),
        EvidenceValidator.normalize('الطاقة الكتلة السرعه'),
      );
    });
  });

  group('EvidenceValidator.verify', () {
    final page = SourcePage(
      pageNumber: 4,
      text: 'الطاقة الحركية للجسم تساوي نصف الكتلة مضروبة في مربع السرعة.',
    );
    final document = _document([
      page,
      const SourcePage(pageNumber: 5, text: ''),
    ]);

    test('accepts an excerpt that is on the cited page', () {
      final result = EvidenceValidator.verify(
        document,
        page: 4,
        excerpt: 'نصف الكتلة مضروبة في مربع السرعة',
      );

      expect(result.isFound, isTrue);
      expect(result.page, 4);
    });

    test('accepts a quote that differs only in Arabic letter forms', () {
      final result = EvidenceValidator.verify(
        document,
        page: 4,
        excerpt: 'الطاقه الحركيه للجسم تساوى نصف الكتله',
      );

      expect(result.isFound, isTrue);
    });

    test('rejects a fabricated excerpt', () {
      final result = EvidenceValidator.verify(
        document,
        page: 4,
        excerpt: 'الطاقة الحركية تساوي الكتلة مضروبة في السرعة',
      );

      expect(result.isFound, isFalse);
      expect(result.failure, EvidenceFailure.notFound);
    });

    test('rejects an excerpt cited to the wrong page', () {
      final result = EvidenceValidator.verify(
        document,
        page: 5,
        excerpt: 'نصف الكتلة مضروبة في مربع السرعة',
      );

      expect(result.isFound, isFalse);
      expect(result.failure, EvidenceFailure.pageEmpty);
    });

    test('rejects a page that is not in the document', () {
      final result = EvidenceValidator.verify(
        document,
        page: 99,
        excerpt: 'نصف الكتلة مضروبة في مربع السرعة',
      );

      expect(result.isFound, isFalse);
      expect(result.failure, EvidenceFailure.pageMissing);
    });

    test('rejects an excerpt too short to prove anything', () {
      final result = EvidenceValidator.verify(
        document,
        page: 4,
        excerpt: 'الطاقة',
      );

      expect(result.isFound, isFalse);
      expect(result.failure, EvidenceFailure.emptyExcerpt);
    });
  });

  group('EvidenceValidator.contains', () {
    test('requires the whole excerpt, not only its first words', () {
      expect(
        EvidenceValidator.contains(
          'الماء يغلي عند مئة درجة مئوية على سطح البحر.',
          'الماء يغلي عند مئة درجة',
        ),
        isTrue,
      );
      expect(
        EvidenceValidator.contains(
          'الماء يغلي عند مئة درجة مئوية على سطح البحر.',
          'الماء يغلي عند مئة درجة فهرنهايت',
        ),
        isFalse,
      );
    });
  });

  group('EvidenceValidator.excerptAround', () {
    test('clamps the window to the text and collapses whitespace', () {
      const text =
          '  أولاً نكتب المعادلة.\nثانياً نعوض بالقيم.\nثالثاً نحسب الناتج.';
      final excerpt = EvidenceValidator.excerptAround(
        text,
        start: text.indexOf('ثانياً'),
        end: text.indexOf('ثانياً') + 'ثانياً نعوض بالقيم'.length,
        before: 2,
        after: 2,
      );

      expect(excerpt.contains('ثانياً نعوض بالقيم'), isTrue);
      expect(excerpt.contains('\n'), isFalse);
      expect(excerpt.contains('أولاً'), isFalse);
    });

    test('survives a match at the very start and very end', () {
      const text = 'بداية النص هنا ونهايته هناك';
      expect(
        EvidenceValidator.excerptAround(
          text,
          start: 0,
          end: 5,
          before: 50,
          after: 0,
        ),
        'بداية',
      );
      expect(
        EvidenceValidator.excerptAround(
          text,
          start: text.length,
          end: text.length,
          before: 0,
          after: 50,
        ),
        isEmpty,
      );
    });
  });
}
