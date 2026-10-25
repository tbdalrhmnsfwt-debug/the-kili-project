import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/official_subject_index.dart';
import '../lib/core/study_library.dart';
import '../lib/models/manhaji.dart';
import '../lib/models/official_book.dart';

/// The catalog shipped with the app, or null when `assets/` is unavailable.
OfficialBookCatalog? _shippedCatalog() {
  final file = File('assets/data/official_books.json');
  if (!file.existsSync()) return null;
  return OfficialBookCatalog.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}

void main() {
  group('officialSubjectKey', () {
    test('folds language and component variants onto the subject', () {
      expect(officialSubjectKey('الرياضيات باللغة الإنجليزية'), 'الرياضيات');
      expect(officialSubjectKey('الرياضيات باللغة العربية'), 'الرياضيات');
      expect(officialSubjectKey('الرياضيات-القصة'), 'الرياضيات');
      expect(
        officialSubjectKey('اللغة الفرنسية-لغة أجنبية أولى-القصة'),
        'اللغة الفرنسية',
      );
      expect(
        officialSubjectKey('اللغة الصينية لغة أجنبية ثانية'),
        officialSubjectKey('اللغة الصينية'),
      );
      expect(
        officialSubjectKey('اللغة الصينية لغة أجنبية ثانية - قديم'),
        officialSubjectKey('اللغة الصينية'),
      );
    });

    test('keeps pure and applied mathematics separate', () {
      expect(
        officialSubjectKey('الرياضيات البحتة باللغة العربية'),
        isNot(officialSubjectKey('الرياضيات')),
      );
      expect(
        officialSubjectKey('تطبيقات الرياضيات باللغة العربية'),
        officialSubjectKey('الرياضيات التطبيقية'),
      );
    });

    test('repairs spelling variants instead of splitting a subject', () {
      expect(
        officialSubjectKey('اللغة الأسبانية'),
        officialSubjectKey('اللغة الإسبانية'),
      );
      expect(
        officialSubjectKey('البرمجة والذكاء الإصطناعي باللغة العربية'),
        officialSubjectKey('البرمجة والذكاء الاصطناعي'),
      );
      expect(
        officialSubjectKey('إدارة الأعمال بالغة الإنجليزية'),
        officialSubjectKey('إدارة الأعمال'),
      );
      expect(officialSubjectKey('االتاريخ الوطنى'), 'التاريخ');
    });

    test('folds development geography and ICT onto bundled subjects', () {
      expect(officialSubjectKey('جغرافيا التنمية'), 'الجغرافيا');
      expect(officialSubjectKey('الجغرافيا السياسية'), 'الجغرافيا');
      expect(
        officialSubjectKey('تكنولوجيا المعلومات والاتصالات'),
        'تكنولوجيا المعلومات',
      );
    });
  });

  group('shipped catalog mapping', () {
    final catalog = _shippedCatalog();

    test('official grade counts match the groups they are built from', () {
      if (catalog == null) return;
      for (final gradeId in const ['sec1', 'sec2', 'sec3']) {
        final counts = officialCountsForGrade(catalog, gradeId);
        final groups = officialSubjectGroups(catalog, gradeId);
        expect(counts.sources, greaterThan(0), reason: gradeId);
        expect(
          counts.books,
          groups.fold<int>(0, (sum, group) => sum + group.books),
          reason: gradeId,
        );
        expect(
          counts.assessments,
          groups.fold<int>(0, (sum, group) => sum + group.assessments),
          reason: gradeId,
        );
        expect(counts.subjects, groups.length, reason: gradeId);
      }
      expect(
        officialCountsForGrade(catalog, 'prep1').isEmpty,
        isTrue,
        reason: 'primary grades have no official rows',
      );
    });

    test('every group has unique keys and something to open', () {
      if (catalog == null) return;
      for (final gradeId in const ['sec1', 'sec2', 'sec3']) {
        final groups = officialSubjectGroups(catalog, gradeId);
        expect(groups, isNotEmpty, reason: gradeId);
        expect(
          groups.map((group) => group.key).toSet().length,
          groups.length,
          reason: gradeId,
        );
        for (final group in groups) {
          expect(group.sources, greaterThan(0), reason: group.key);
          expect(
            group.rows.every((row) => row.grade == gradeId && !row.isNotice),
            isTrue,
            reason: group.key,
          );
          expect(
            group.rows.every(
              (row) => officialSubjectKey(row.subject) == group.key,
            ),
            isTrue,
            reason: group.key,
          );
        }
      }
    });

    test('every official-only subject is reachable by its route name', () {
      if (catalog == null) return;
      for (final gradeId in const ['sec1', 'sec2', 'sec3']) {
        final grade = Grade(id: gradeId, label: gradeId, books: const []);
        final subjects = studySubjects(
          grade,
          const {},
          officialCatalog: catalog,
        );
        final byKey = {
          for (final subject in subjects)
            officialSubjectKey(subject.name): subject,
        };
        expect(byKey.length, subjects.length, reason: gradeId);
        for (final group in officialSubjectGroups(catalog, gradeId)) {
          final subject = byKey[group.key];
          expect(subject, isNotNull, reason: '${gradeId}/${group.key}');
          expect(
            subject!.isOfficialOnly,
            isTrue,
            reason: '${gradeId}/${group.key} has no bundled books',
          );
          expect(
            officialRowsForSubject(catalog, gradeId, subject.name),
            isNotEmpty,
            reason: '${gradeId}/${group.key} route name must resolve',
          );
        }
      }
    });

    test('general and pure mathematics never leak into each other', () {
      if (catalog == null) return;
      final general = officialRowsForSubject(catalog, 'sec2', 'الرياضيات');
      final pure = officialRowsForSubject(catalog, 'sec2', 'الرياضيات البحتة');
      expect(general, isNotEmpty);
      expect(pure, isNotEmpty);
      expect(
        general.every(
          (book) => officialSubjectKey(book.subject) == 'الرياضيات',
        ),
        isTrue,
      );
      expect(
        pure.every(
          (book) => officialSubjectKey(book.subject) == 'الرياضيات البحتة',
        ),
        isTrue,
      );
    });

    test('a subject list spans both education systems', () {
      if (catalog == null) return;
      final arabic = officialRowsForSubject(catalog, 'sec2', 'اللغة العربية');
      expect(
        arabic.any((book) => book.system == EducationSystem.generalSecondary),
        isTrue,
      );
      expect(
        arabic.any(
          (book) => book.system == EducationSystem.egyptianBaccalaureate,
        ),
        isTrue,
      );
    });

    test('notices never become a subject or a book row', () {
      if (catalog == null) return;
      for (final gradeId in const ['sec1', 'sec2', 'sec3']) {
        expect(
          officialSubjectGroups(
            catalog,
            gradeId,
          ).where((group) => group.displayName == 'الكتب الرسمية'),
          isEmpty,
          reason: gradeId,
        );
        expect(
          officialRowsForSubject(catalog, gradeId, 'الكتب الرسمية'),
          isEmpty,
          reason: gradeId,
        );
      }
    });
  });
}
