import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/book_storage.dart';
import '../lib/models/official_book.dart';

OfficialBook _book({
  String id = 'book-1',
  EducationSystem system = EducationSystem.generalSecondary,
  BaccalaureatePathway track = BaccalaureatePathway.none,
  String grade = 'sec1',
  String schoolYear = '2026-2027',
  String language = 'ar',
  BookTerm term = BookTerm.first,
  String subjectId = 'math',
  OfficialBookStatus status = OfficialBookStatus.available,
  String downloadUrl =
      'https://elearnningcontent.blob.core.windows.net/books/book-1.pdf',
}) => OfficialBook(
  id: id,
  grade: grade,
  subject: 'الرياضيات',
  subjectId: subjectId,
  titleAr: 'الرياضيات',
  system: system,
  track: track,
  term: term,
  schoolYear: schoolYear,
  language: language,
  downloadUrl: downloadUrl,
  status: status,
  officialSourceUrl: 'https://ellibrary.moe.gov.eg/Books-sec/',
  sourcePage: 'https://ellibrary.moe.gov.eg/Books-sec/',
);

void main() {
  group('OfficialBookUrlPolicy', () {
    const policy = OfficialBookUrlPolicy();

    test('accepts an exact Ministry PDF URL', () {
      final uri = policy.requireDownloadUrl(
        'https://elearnningcontent.blob.core.windows.net/books/math.pdf',
      );
      expect(uri.host, 'elearnningcontent.blob.core.windows.net');
    });

    test('accepts the Baccalaureate host', () {
      expect(
        policy
            .requireDownloadUrl(
              'https://egyptianbaccalaureate.blob.core.windows.net/x.pdf',
            )
            .scheme,
        'https',
      );
    });

    test('rejects plain HTTP', () {
      expect(
        () => policy.requireDownloadUrl(
          'http://elearnningcontent.blob.core.windows.net/x.pdf',
        ),
        throwsA(
          isA<BookOperationException>().having(
            (error) => error.kind,
            'kind',
            BookFailureKind.invalidUrl,
          ),
        ),
      );
    });

    test('rejects a non-Ministry host, including look-alikes', () {
      for (final url in [
        'https://example.com/x.pdf',
        'https://moe.gov.eg.evil.example/x.pdf',
        'https://elearnningcontent.blob.core.windows.net.evil.example/x.pdf',
        'https://evil.example/elearnningcontent.blob.core.windows.net/x.pdf',
      ]) {
        expect(
          () => policy.requireDownloadUrl(url),
          throwsA(
            isA<BookOperationException>().having(
              (error) => error.kind,
              'kind',
              BookFailureKind.blockedHost,
            ),
          ),
          reason: url,
        );
      }
    });

    test('rejects malformed URLs and embedded credentials', () {
      expect(
        () => policy.requireDownloadUrl(''),
        throwsA(isA<BookOperationException>()),
      );
      expect(
        () => policy.requireDownloadUrl('not a url'),
        throwsA(isA<BookOperationException>()),
      );
      expect(
        () => policy.requireDownloadUrl(
          'https://user:pass@elearnningcontent.blob.core.windows.net/x.pdf',
        ),
        throwsA(
          isA<BookOperationException>().having(
            (error) => error.kind,
            'kind',
            BookFailureKind.invalidUrl,
          ),
        ),
      );
    });

    test('rejects a redirect that leaves the allowlist', () {
      expect(
        () => policy.requireFinalUrl(Uri.parse('https://evil.example/x.pdf')),
        throwsA(
          isA<BookOperationException>().having(
            (error) => error.kind,
            'kind',
            BookFailureKind.blockedHost,
          ),
        ),
      );
      policy.requireFinalUrl(
        Uri.parse('https://elearnningcontent.blob.core.windows.net/x.pdf'),
      );
    });
  });

  group('BookStorageLayout', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('thakir-storage-test-');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('stores year/system/grade/stream/subject/language/term/book', () {
      final book = _book(
        system: EducationSystem.egyptianBaccalaureate,
        track: BaccalaureatePathway.medicineLifeSciences,
        grade: 'sec2',
        subjectId: 'biology',
        language: 'en',
      );
      final layout = BookStorageLayout(root);
      final relative = layout.relativeBookDirectory(book).split(
        Platform.pathSeparator,
      );

      expect(relative, [
        '2026-2027',
        'egyptian_baccalaureate',
        'sec2',
        'medicine_life_sciences',
        'biology',
        'en',
        'term1',
        'book-1',
      ]);
      expect(layout.finalFile(book).path, endsWith('book.pdf'));
      expect(layout.partialFile(book).path, endsWith('book.pdf.part'));
    });

    test('marks general-secondary books as streamless', () {
      final relative = BookStorageLayout(root).relativeBookDirectory(_book());
      expect(relative, contains('no-stream'));
      expect(relative, contains('general_secondary'));
    });

    test('the same catalog row always maps to one shared file', () {
      final layout = BookStorageLayout(root);
      final a = layout.finalFile(_book());
      final b = layout.finalFile(_book());
      expect(a.path, b.path);
    });

    test('different grades, terms or languages never collide', () {
      final layout = BookStorageLayout(root);
      final paths = {
        layout.finalFile(_book()).path,
        layout.finalFile(_book(grade: 'sec2')).path,
        layout.finalFile(_book(language: 'fr')).path,
        layout.finalFile(_book(term: BookTerm.second)).path,
        layout.finalFile(_book(subjectId: 'physics')).path,
      };
      expect(paths, hasLength(5));
    });

    test('safeSegment keeps ASCII IDs and derives stable Arabic fallbacks', () {
      expect(BookStorageLayout.safeSegment('Math_Sec1'), 'math_sec1');
      expect(BookStorageLayout.safeSegment('a/b c'), 'a-b-c');
      final first = BookStorageLayout.safeSegment('الرياضيات');
      final second = BookStorageLayout.safeSegment('الرياضيات');
      expect(first, startsWith('item-'));
      expect(first, second);
      expect(first, isNot(BookStorageLayout.safeSegment('الفيزياء')));
    });

    test('extraction is versioned by the verified SHA', () {
      final book = _book();
      final layout = BookStorageLayout(root);
      final one = layout.extractionFile(book, 'a' * 64).path;
      final two = layout.extractionFile(book, 'b' * 64).path;
      expect(one, isNot(two));
      expect(one, contains('pages_${'a' * 16}.json'));
      expect(
        layout.extractionFile(book, 'a' * 64).path,
        layout.extractionFile(book, 'a' * 64).path,
      );
    });
  });

  group('shipped catalog', () {
    final file = File('assets/data/official_books.json');

    test('exists and parses', () {
      expect(file.existsSync(), isTrue);
      final catalog = OfficialBookCatalog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(catalog.schoolYear, '2026-2027');
      expect(catalog.books, isNotEmpty);
      expect(catalog.sources, isNotEmpty);
    });

    test('has unique ids and complete metadata', () {
      final catalog = OfficialBookCatalog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      final ids = <String>{};
      for (final book in catalog.books) {
        expect(book.id, isNotEmpty);
        expect(ids.add(book.id), isTrue, reason: 'duplicate id ${book.id}');
        expect(book.titleAr, isNotEmpty, reason: book.id);
        expect(book.subject, isNotEmpty, reason: book.id);
        expect(book.grade, anyOf('sec1', 'sec2', 'sec3'), reason: book.id);
        expect(book.schoolYear, '2026-2027', reason: book.id);
        expect(book.officialSourceUrl, startsWith('https://'), reason: book.id);
        expect(book.sourcePage, startsWith('https://'), reason: book.id);
        final sourceHost = Uri.parse(book.sourcePage).host;
        expect(
          kOfficialSourceHosts,
          contains(sourceHost),
          reason: 'unexpected source host for ${book.id}: $sourceHost',
        );
      }
    });

    test('every published link is on a Ministry host', () {
      const policy = OfficialBookUrlPolicy();
      final catalog = OfficialBookCatalog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      var published = 0;
      for (final book in catalog.books) {
        if (book.status != OfficialBookStatus.available) {
          // A row awaiting review may keep the URL it was found on, but it is
          // never offered for download until a human verifies it.
          expect(book.hasDownload, isFalse, reason: book.id);
          if (book.status == OfficialBookStatus.notPublished) {
            expect(book.downloadUrl, isEmpty, reason: book.id);
          }
          continue;
        }
        published++;
        expect(book.downloadUrl, isNotEmpty, reason: book.id);
        expect(
          () => policy.requireDownloadUrl(book.downloadUrl),
          returnsNormally,
          reason: book.id,
        );
      }
      expect(published, greaterThan(300));
    });

    test('never mixes General Secondary with Baccalaureate', () {
      final catalog = OfficialBookCatalog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      for (final book in catalog.books) {
        if (book.system == EducationSystem.generalSecondary) {
          expect(book.track, BaccalaureatePathway.none, reason: book.id);
        }
        if (book.system == EducationSystem.egyptianBaccalaureate) {
          expect(book.grade, isNot('sec1'), reason: book.id);
        }
      }

      final general = catalog.forSystem(EducationSystem.generalSecondary);
      final bac = catalog.forSystem(EducationSystem.egyptianBaccalaureate);
      expect(general, isNotEmpty);
      expect(bac, isNotEmpty);
      expect(
        general.every(
          (book) => book.system == EducationSystem.generalSecondary,
        ),
        isTrue,
      );
      expect(
        bac.every(
          (book) => book.system == EducationSystem.egyptianBaccalaureate,
        ),
        isTrue,
      );
    });

    test('Baccalaureate pathway filters include shared core subjects', () {
      final catalog = OfficialBookCatalog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      final medicine = catalog.forSystem(
        EducationSystem.egyptianBaccalaureate,
        grade: 'sec2',
        pathway: BaccalaureatePathway.medicineLifeSciences,
      );
      expect(medicine, isNotEmpty);
      expect(
        medicine.every(
          (book) =>
              book.track == BaccalaureatePathway.medicineLifeSciences ||
              book.track == BaccalaureatePathway.none,
        ),
        isTrue,
      );

      final business = catalog.forSystem(
        EducationSystem.egyptianBaccalaureate,
        grade: 'sec2',
        pathway: BaccalaureatePathway.business,
      );
      expect(
        business.any((book) => book.subject.contains('المحاسبة')),
        isTrue,
        reason: 'Business pathway should show its accounting book',
      );
    });

    test('a row without a URL is not published and has no fake link', () {
      final book = OfficialBook.fromJson({
        'id': 'future-book',
        'grade': 'sec3',
        'subject': 'مادة جديدة',
        'title_ar': 'مادة جديدة',
        'system': 'general_secondary',
      });
      expect(book.status, OfficialBookStatus.notPublished);
      expect(book.downloadUrl, isEmpty);
      expect(book.hasDownload, isFalse);
      expect(book.initialState().downloadStatus, BookDownloadStatus.notPublished);
      expect(book.statusExplanation, contains('لم يُنشر'));
    });

    test('initial local state follows the catalog status', () {
      expect(
        _book().initialState().downloadStatus,
        BookDownloadStatus.notDownloaded,
      );
      expect(
        _book(status: OfficialBookStatus.manualReview)
            .initialState()
            .downloadStatus,
        BookDownloadStatus.manualReview,
      );
      expect(
        _book(status: OfficialBookStatus.retired)
            .initialState()
            .downloadStatus,
        BookDownloadStatus.failed,
      );
    });
  });
}
