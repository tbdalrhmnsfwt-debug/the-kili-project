/// Official-book storage policy and URL guard.
///
/// The Ministry's PDF hosts are the only hosts the downloader is allowed to
/// use. Redirects are checked again after they resolve, so an allowlisted URL
/// cannot bounce the download to an unrelated server.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/official_book.dart';

/// The two Ministry-controlled hosts that serve the official 2026–2027 PDFs.
const Set<String> kOfficialPdfHosts = {
  'elearnningcontent.blob.core.windows.net',
  'egyptianbaccalaureate.blob.core.windows.net',
};

/// The official source pages, used by diagnostics only.
const Set<String> kOfficialSourceHosts = {
  'ellibrary.moe.gov.eg',
  'moe.gov.eg',
  'elearnningcontent.blob.core.windows.net',
  'egyptianbaccalaureate.blob.core.windows.net',
};

/// The kinds of failure surfaced to the student in Arabic.
enum BookFailureKind {
  invalidUrl,
  blockedHost,
  notAvailable,
  network,
  timeout,
  http,
  contentType,
  signature,
  unreadable,
  storage,
  cancelled,
  duplicate,
  unknown,
}

/// A download/extraction failure with a stable kind and Arabic message.
class BookOperationException implements Exception {
  const BookOperationException(
    this.kind,
    this.message, {
    this.cause,
    this.statusCode,
  });

  final BookFailureKind kind;
  final String message;
  final Object? cause;
  final int? statusCode;

  @override
  String toString() => 'BookOperationException(${kind.name}): $message';
}

/// URI validation for official PDF links.
class OfficialBookUrlPolicy {
  const OfficialBookUrlPolicy({this.allowedHosts = kOfficialPdfHosts});

  final Set<String> allowedHosts;

  /// Throws a [BookOperationException] when [raw] is not a safe PDF URL.
  Uri requireDownloadUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const BookOperationException(
        BookFailureKind.invalidUrl,
        'رابط الكتاب غير صالح. لم يتم بدء التنزيل.',
      );
    }
    if (uri.scheme != 'https') {
      throw const BookOperationException(
        BookFailureKind.invalidUrl,
        'رابط الكتاب لازم يكون HTTPS من مصدر رسمي.',
      );
    }
    if (!allowedHosts.contains(uri.host.toLowerCase())) {
      throw BookOperationException(
        BookFailureKind.blockedHost,
        'المصدر «${uri.host}» مش ضمن مصادر الوزارة المسموح بها.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const BookOperationException(
        BookFailureKind.invalidUrl,
        'رابط الكتاب فيه بيانات دخول غير مسموح بها.',
      );
    }
    return uri;
  }

  /// Validates the URL a redirect actually landed on.
  void requireFinalUrl(Uri uri) {
    if (uri.scheme != 'https' || !allowedHosts.contains(uri.host.toLowerCase())) {
      throw BookOperationException(
        BookFailureKind.blockedHost,
        'التنزيل اتحوّل لمصدر غير رسمي (${uri.host}) واتوقف للأمان.',
      );
    }
  }
}

/// Where a book's PDF, partial file, manifest and extracted JSON live.
///
/// Paths are ASCII-only on purpose: the metadata, not the filesystem, is the
/// source of truth for Arabic titles. The layout follows
/// `year/system/grade/pathway/subject/language/term/book-id`.
class BookStorageLayout {
  const BookStorageLayout(this.root);

  final Directory root;

  /// A filesystem-safe token. IDs and slugs come from the generated catalog
  /// already ASCII; this is the final line of defence for imported catalogs.
  static String safeSegment(String input, {String fallback = 'item'}) {
    final cleaned = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (cleaned.isEmpty) {
      final hash = _fnv1a(input);
      return '$fallback-$hash';
    }
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  String relativeBookDirectory(OfficialBook book) {
    final track = book.track == BaccalaureatePathway.none
        ? 'no-stream'
        : book.track.wire;
    return p.join(
      safeSegment(book.schoolYear, fallback: 'year'),
      book.system.wire,
      safeSegment(book.grade, fallback: 'grade'),
      track,
      safeSegment(book.subjectId, fallback: 'subject'),
      safeSegment(book.language, fallback: 'language'),
      book.term.wire,
      safeSegment(book.id, fallback: 'book'),
    );
  }

  Directory bookDirectory(OfficialBook book) =>
      Directory(p.join(root.path, relativeBookDirectory(book)));

  /// The final, validated PDF. A new version is never written over this file
  /// until it has been fully downloaded and validated.
  File finalFile(OfficialBook book) =>
      File(p.join(bookDirectory(book).path, 'book.pdf'));

  File partialFile(OfficialBook book) =>
      File(p.join(bookDirectory(book).path, 'book.pdf.part'));

  File manifestFile(OfficialBook book) =>
      File(p.join(bookDirectory(book).path, 'book_manifest.json'));

  /// Versioned, page-numbered extraction. Keyed by the verified SHA so a new
  /// edition cannot overwrite the old extraction.
  File extractionFile(OfficialBook book, String sha256) {
    final digest = sha256.length >= 16 ? sha256.substring(0, 16) : sha256;
    return File(
      p.join(
        root.path,
        safeSegment(book.schoolYear, fallback: 'year'),
        'extracted',
        safeSegment(book.id, fallback: 'book'),
        'pages_$digest.json',
      ),
    );
  }

  /// An in-progress extraction, written atomically at checkpoints so a crash
  /// can resume instead of re-reading hundreds of pages.
  File partialExtractionFile(OfficialBook book, String sha256) {
    final digest = sha256.length >= 16 ? sha256.substring(0, 16) : sha256;
    return File(
      p.join(
        root.path,
        safeSegment(book.schoolYear, fallback: 'year'),
        'extracted',
        safeSegment(book.id, fallback: 'book'),
        'pages_$digest.partial.json',
      ),
    );
  }

  File extractedManifestFile(OfficialBook book) => File(
    p.join(
      root.path,
      safeSegment(book.schoolYear, fallback: 'year'),
      'extracted',
      safeSegment(book.id, fallback: 'book'),
      'manifest.json',
    ),
  );

  /// Keeps the previous verified PDF rather than deleting it when an update
  /// replaces it.
  File previousFile(OfficialBook book, DateTime when) => File(
    p.join(
      bookDirectory(book).path,
      'book.previous.${when.millisecondsSinceEpoch}.pdf',
    ),
  );

  Future<void> ensureBookDirectory(OfficialBook book) async {
    await bookDirectory(book).create(recursive: true);
  }

  Future<void> ensureExtractionDirectory(OfficialBook book) async {
    await extractionFile(book, '0000000000000000').parent.create(
      recursive: true,
    );
  }
}

String _fnv1a(String value) {
  var hash = 0x811c9dc5;
  for (final code in value.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
