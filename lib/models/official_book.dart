/// Official Egyptian Ministry of Education textbook catalog and local
/// download/extraction state.
///
/// The catalog itself is read-only data generated from the Ministry's
/// 2026–2027 e-library indexes. Nothing here guesses a PDF address: an entry
/// only carries a [downloadUrl] when that exact link appeared on an official
/// Ministry page. Entries that are not published yet are represented with
/// [OfficialBookStatus.notPublished] and no URL.
///
/// The model is deliberately Flutter-free so the catalog can be verified with
/// a plain Dart script before the app is built.
library;

/// The education system an official book belongs to.
enum EducationSystem {
  generalSecondary('general_secondary', 'الثانوي العام', 'عام'),
  egyptianBaccalaureate(
    'egyptian_baccalaureate',
    'البكالوريا المصرية',
    'بكالوريا',
  );

  const EducationSystem(this.wire, this.label, this.shortLabel);

  final String wire;
  final String label;
  final String shortLabel;

  static EducationSystem fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final system in values) {
      if (system.wire == raw || system.name == raw) return system;
    }
    if (raw.contains('بكالوريا')) return egyptianBaccalaureate;
    return generalSecondary;
  }
}

/// The official publication state of a catalog row.
///
/// This is *not* the download state. A book can be officially available and
/// still not be downloaded on this device.
enum OfficialBookStatus {
  available('available', 'متاح رسميًا'),
  notPublished('not_published', 'لم يُنشر بعد'),
  manualReview('manual_review', 'يحتاج مراجعة'),
  retired('retired', 'غير متاح');

  const OfficialBookStatus(this.wire, this.label);

  final String wire;
  final String label;

  static OfficialBookStatus fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final status in values) {
      if (status.wire == raw || status.name == raw) return status;
    }
    return available;
  }
}

/// The state of the downloadable PDF on this device.
enum BookDownloadStatus {
  notDownloaded('not_downloaded', 'غير منزّل'),
  queued('queued', 'في الانتظار'),
  downloading('downloading', 'بيتنزّل'),
  downloaded('downloaded', 'منزّل'),
  failed('failed', 'فشل التنزيل'),
  needsUpdate('needs_update', 'فيه تحديث'),
  cancelled('cancelled', 'اتلغى'),
  notPublished('not_published', 'لم يُنشر بعد'),
  manualReview('manual_review', 'يحتاج مراجعة');

  const BookDownloadStatus(this.wire, this.label);

  final String wire;
  final String label;

  bool get isBusy => this == queued || this == downloading;

  static BookDownloadStatus fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final status in values) {
      if (status.wire == raw || status.name == raw) return status;
    }
    return notDownloaded;
  }
}

/// The state of turning a downloaded PDF into a searchable lesson library.
enum BookExtractionStatus {
  notStarted('not_started', 'لم يبدأ الاستخراج'),
  extracting('extracting', 'بيستخرج النص'),
  organizing('organizing', 'بيرتّب الدروس'),
  ready('ready', 'جاهز للمذاكرة'),
  needsReview('needs_review', 'يحتاج مراجعة'),
  failed('failed', 'فشل الاستخراج');

  const BookExtractionStatus(this.wire, this.label);

  final String wire;
  final String label;

  static BookExtractionStatus fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final status in values) {
      if (status.wire == raw || status.name == raw) return status;
    }
    return notStarted;
  }
}

/// What kind of official resource a row points at.
enum OfficialResourceKind {
  studentBook('student_book', 'كتاب الطالب'),
  assessment('assessment', 'تقييمات وأداءات'),
  story('story', 'قصة'),
  workbook('workbook', 'كراسة تدريبات'),
  activity('activity', 'نشاط'),
  notice('notice', 'بيان رسمي'),
  reference('reference', 'مرجع');

  const OfficialResourceKind(this.wire, this.label);

  final String wire;
  final String label;

  static OfficialResourceKind fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final kind in values) {
      if (kind.wire == raw || kind.name == raw) return kind;
    }
    return studentBook;
  }
}

/// How the official index scopes a resource.
///
/// The General Secondary index does not state streams, so its rows are
/// [notSpecified] rather than being presented as compulsory for everyone.
enum OfficialRequirement {
  notSpecified('not_specified', 'غير محددة في الفهرس الرسمي'),
  core('core', 'مادة أساسية'),
  pathway('pathway', 'مادة مسار'),
  optional('optional', 'نشاط اختياري');

  const OfficialRequirement(this.wire, this.label);

  final String wire;
  final String label;

  static OfficialRequirement fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final requirement in values) {
      if (requirement.wire == raw || requirement.name == raw) {
        return requirement;
      }
    }
    return notSpecified;
  }
}

/// The Egyptian Baccalaureate pathway named by the official source.
///
/// Grade 12 pathways are listed because the system is announced, but the
/// Grade 12 books themselves are not published yet. Only the Grade 11
/// (الصف الثاني) catalog is currently verified.
enum BaccalaureatePathway {
  none('', 'غير محدد'),
  medicineLifeSciences('medicine_life_sciences', 'الطب وعلوم الحياة'),
  engineeringComputerScience(
    'engineering_computer_science',
    'الهندسة وعلوم الحاسب',
  ),
  business('business', 'الأعمال'),
  artsHumanities('arts_humanities', 'الآداب والفنون');

  const BaccalaureatePathway(this.wire, this.label);

  final String wire;
  final String label;

  static BaccalaureatePathway fromWire(Object? value) {
    final raw = '$value'.trim();
    for (final pathway in values) {
      if (pathway.wire == raw || pathway.name == raw) return pathway;
    }
    return none;
  }
}

/// A school term.
enum BookTerm {
  first('term1', 'الفصل الدراسي الأول'),
  second('term2', 'الفصل الدراسي الثاني'),
  fullYear('full_year', 'العام الدراسي كامل');

  const BookTerm(this.wire, this.label);

  final String wire;
  final String label;

  static BookTerm fromWire(Object? value) {
    final raw = '$value'.trim();
    if (raw.contains('ثانى') || raw.contains('ثاني')) return second;
    if (raw.contains('كامل') || raw == 'full_year') return fullYear;
    for (final term in values) {
      if (term.wire == raw || term.name == raw) return term;
    }
    return first;
  }
}

/// A verified official source page.
class OfficialSource {
  const OfficialSource({
    required this.id,
    required this.title,
    required this.url,
    required this.verifiedAt,
    this.publisher = 'وزارة التربية والتعليم والتعليم الفني',
    this.notes = '',
  });

  final String id;
  final String title;
  final String url;
  final String verifiedAt;
  final String publisher;
  final String notes;

  factory OfficialSource.fromJson(Map<String, dynamic> json) => OfficialSource(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    verifiedAt: json['verified_at'] as String? ?? '',
    publisher: json['publisher'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'verified_at': verifiedAt,
    'publisher': publisher,
    if (notes.isNotEmpty) 'notes': notes,
  };
}

/// One official textbook (or assessment/activity) in the catalog.
class OfficialBook {
  const OfficialBook({
    required this.id,
    required this.grade,
    required this.subject,
    required this.titleAr,
    required this.system,
    this.titleEn = '',
    this.subjectId = '',
    this.track = BaccalaureatePathway.none,
    this.term = BookTerm.first,
    this.schoolYear = '2026-2027',
    this.language = 'ar',
    this.edition = '',
    this.publisher = 'وزارة التربية والتعليم والتعليم الفني',
    this.officialSourceUrl = '',
    this.downloadUrl = '',
    this.sourcePage = '',
    this.status = OfficialBookStatus.available,
    this.resourceKind = OfficialResourceKind.studentBook,
    this.requirement = OfficialRequirement.notSpecified,
    this.metadataVersion = '1',
    this.part = '',
    this.component = '',
    this.sourceNote = '',
    this.expectedSha256 = '',
  });

  /// Stable, ASCII-only identifier used for storage paths and state keys.
  final String id;

  /// One of `sec1`, `sec2`, `sec3` (prep/primary are not in this catalog yet).
  final String grade;

  /// The exact Arabic subject label from the Ministry index.
  final String subject;

  /// Convenience grouping key, e.g. `الرياضيات` for all language variants.
  final String subjectId;

  final String titleAr;
  final String titleEn;
  final EducationSystem system;
  final BaccalaureatePathway track;
  final BookTerm term;
  final String schoolYear;

  /// BCP-47-ish language tag (`ar`, `en`, `fr`, …).
  final String language;

  final String edition;
  final String publisher;

  /// The verified catalog page that lists this book.
  final String officialSourceUrl;

  /// The exact PDF URL published by the Ministry. Empty when not published.
  final String downloadUrl;

  /// The same catalog page, kept under the spec's `source_page` name.
  final String sourcePage;

  final OfficialBookStatus status;
  final OfficialResourceKind resourceKind;
  final OfficialRequirement requirement;

  /// Version of the catalog row that produced this record.
  final String metadataVersion;

  /// For multi-part books: `1`, `2`, or `story` / `workbook`.
  final String part;

  /// The component qualifier, e.g. `القصة` or `كراسة التدريبات`.
  final String component;

  /// Provenance notes, including why a row is [OfficialBookStatus.manualReview].
  final String sourceNote;

  /// Present only when the source page published a checksum. The Ministry does
  /// not publish hashes today, so this is usually empty.
  final String expectedSha256;

  /// Backwards-compatible getter used by the original catalog UI.
  String get url => downloadUrl;

  /// Backwards-compatible getter used by the original catalog UI.
  String get source => sourcePage.isNotEmpty ? sourcePage : officialSourceUrl;

  /// Backwards-compatible getter used by the original catalog UI.
  String get title => titleAr;

  bool get hasDownload =>
      downloadUrl.isNotEmpty && status == OfficialBookStatus.available;

  bool get isPublished => status == OfficialBookStatus.available;

  bool get isNotice => resourceKind == OfficialResourceKind.notice;

  String get gradeLabel => gradeLabels[grade] ?? grade;

  String get pathwayLabel => system == EducationSystem.egyptianBaccalaureate
      ? track.label
      : 'غير محدد في الفهرس الرسمي';

  String get languageLabel => languageLabels[language] ?? language;

  /// The last path segment of the published PDF, without query parameters.
  String get fileName {
    if (downloadUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(downloadUrl);
      final raw = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      return Uri.decodeComponent(raw).replaceAll(RegExp(r'\.pdf\.pdf$'), '.pdf');
    } catch (_) {
      return '';
    }
  }

  /// An Arabic sentence explaining the catalog status, ready for the UI.
  String get statusExplanation => switch (status) {
    OfficialBookStatus.available =>
      'الرابط منشور على صفحة رسمية بوزارة التربية والتعليم.',
    OfficialBookStatus.notPublished =>
      'لم يُنشر الكتاب الرسمي بعد. التطبيق لا يخترع رابطًا بديلًا.',
    OfficialBookStatus.manualReview =>
      sourceNote.isNotEmpty
          ? sourceNote
          : 'بيانات المصدر تحتاج مراجعة بشرية قبل التنزيل.',
    OfficialBookStatus.retired => 'الرابط لم يعد متاحًا في الفهرس الرسمي.',
  };

  /// The initial local state implied by the catalog row.
  BookLocalState initialState() => BookLocalState(
    bookId: id,
    downloadStatus: switch (status) {
      OfficialBookStatus.available => BookDownloadStatus.notDownloaded,
      OfficialBookStatus.notPublished => BookDownloadStatus.notPublished,
      OfficialBookStatus.manualReview => BookDownloadStatus.manualReview,
      OfficialBookStatus.retired => BookDownloadStatus.failed,
    },
    metadataVersion: metadataVersion,
  );

  factory OfficialBook.fromJson(Map<String, dynamic> json) {
    final url =
        _string(json['download_url']) ??
        _string(json['downloadUrl']) ??
        _string(json['url']) ??
        '';
    final sourcePage =
        _string(json['source_page']) ??
        _string(json['sourcePage']) ??
        _string(json['source']) ??
        '';
    final officialSource =
        _string(json['official_source_url']) ??
        _string(json['officialSourceUrl']) ??
        sourcePage;
    final system = EducationSystem.fromWire(json['system']);
    final rawStatus = json['status'];
    final status = rawStatus == null
        ? (url.isEmpty
              ? OfficialBookStatus.notPublished
              : OfficialBookStatus.available)
        : OfficialBookStatus.fromWire(rawStatus);
    return OfficialBook(
      id: _string(json['id']) ?? '',
      grade: _string(json['grade']) ?? '',
      subject: _string(json['subject']) ?? '',
      subjectId:
          _string(json['subject_id']) ?? normalizeSubject(_string(json['subject']) ?? ''),
      titleAr:
          _string(json['title_ar']) ??
          _string(json['titleAr']) ??
          _string(json['title']) ??
          '',
      titleEn: _string(json['title_en']) ?? _string(json['titleEn']) ?? '',
      system: system,
      track: BaccalaureatePathway.fromWire(
        json['track'] ?? json['stream'] ?? json['pathway'],
      ),
      term: BookTerm.fromWire(json['term']),
      schoolYear:
          _string(json['school_year']) ??
          _string(json['schoolYear']) ??
          '2026-2027',
      language: _string(json['language']) ?? _string(json['lang']) ?? 'ar',
      edition: _string(json['edition']) ?? '',
      publisher:
          _string(json['publisher']) ??
          'وزارة التربية والتعليم والتعليم الفني',
      officialSourceUrl: officialSource,
      downloadUrl: url,
      sourcePage: sourcePage,
      status: status,
      resourceKind: OfficialResourceKind.fromWire(
        json['resource_kind'] ?? json['kind'] ?? json['type'],
      ),
      requirement: OfficialRequirement.fromWire(json['requirement']),
      metadataVersion: _string(json['metadata_version']) ?? '1',
      part: _string(json['part']) ?? '',
      component: _string(json['component']) ?? '',
      sourceNote: _string(json['source_note']) ?? '',
      expectedSha256: _string(json['sha256']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title_ar': titleAr,
    'title_en': titleEn,
    'subject': subject,
    'subject_id': subjectId,
    'grade': grade,
    'system': system.wire,
    'track': track.wire,
    'term': term.wire,
    'school_year': schoolYear,
    'language': language,
    'edition': edition,
    'publisher': publisher,
    'official_source_url': officialSourceUrl,
    'download_url': downloadUrl,
    'source_page': sourcePage,
    'status': status.wire,
    'resource_kind': resourceKind.wire,
    'requirement': requirement.wire,
    'metadata_version': metadataVersion,
    if (part.isNotEmpty) 'part': part,
    if (component.isNotEmpty) 'component': component,
    if (sourceNote.isNotEmpty) 'source_note': sourceNote,
    if (expectedSha256.isNotEmpty) 'sha256': expectedSha256,
    // Kept so older builds of the app can still read a newer asset.
    'url': downloadUrl,
    'source': sourcePage,
    'title': titleAr,
  };

  @override
  String toString() => 'OfficialBook($id, $titleAr)';
}

/// Persistent per-device state for an [OfficialBook].
class BookLocalState {
  const BookLocalState({
    required this.bookId,
    this.downloadStatus = BookDownloadStatus.notDownloaded,
    this.extractionStatus = BookExtractionStatus.notStarted,
    this.filePath = '',
    this.fileSize = 0,
    this.sha256 = '',
    this.downloadedAt,
    this.lastCheckedAt,
    this.updatedAt,
    this.etag = '',
    this.lastModified = '',
    this.error = '',
    this.progress = 0,
    this.attempts = 0,
    this.duplicateOf = '',
    this.extractedPath = '',
    this.extractedAt,
    this.pageCount = 0,
    this.sectionCount = 0,
    this.ocrPages = 0,
    this.warnings = const [],
    this.downloadedMetadataVersion = '',
    this.metadataVersion = '',
  });

  final String bookId;
  final BookDownloadStatus downloadStatus;
  final BookExtractionStatus extractionStatus;

  /// Absolute path to the validated PDF. Never removed automatically.
  final String filePath;
  final int fileSize;

  /// SHA-256 of [filePath], lowercase hexadecimal.
  final String sha256;

  final DateTime? downloadedAt;
  final DateTime? lastCheckedAt;
  final DateTime? updatedAt;

  /// HTTP validators captured during download, used by update checks.
  final String etag;
  final String lastModified;

  /// A user-facing Arabic error, empty when there is none.
  final String error;
  final double progress;
  final int attempts;

  /// The id of the canonical book this PDF is shared with, when duplicate
  /// content was detected. The duplicate file is removed; the canonical file
  /// remains.
  final String duplicateOf;

  /// Absolute path to the extracted, page-numbered JSON.
  final String extractedPath;
  final DateTime? extractedAt;
  final int pageCount;
  final int sectionCount;
  final int ocrPages;
  final List<String> warnings;

  /// The catalog's metadata version at download time. When it differs from the
  /// current catalog row, the UI offers a re-check.
  final String downloadedMetadataVersion;
  final String metadataVersion;

  bool get hasFile => filePath.isNotEmpty;
  bool get hasExtraction => extractedPath.isNotEmpty;

  bool get isReadyForLearning =>
      downloadStatus == BookDownloadStatus.downloaded &&
      extractionStatus == BookExtractionStatus.ready;

  BookLocalState copyWith({
    BookDownloadStatus? downloadStatus,
    BookExtractionStatus? extractionStatus,
    String? filePath,
    int? fileSize,
    String? sha256,
    DateTime? downloadedAt,
    DateTime? lastCheckedAt,
    DateTime? updatedAt,
    String? etag,
    String? lastModified,
    String? error,
    double? progress,
    int? attempts,
    String? duplicateOf,
    String? extractedPath,
    DateTime? extractedAt,
    int? pageCount,
    int? sectionCount,
    int? ocrPages,
    List<String>? warnings,
    String? downloadedMetadataVersion,
    String? metadataVersion,
    bool clearError = false,
    bool clearDuplicateOf = false,
  }) => BookLocalState(
    bookId: bookId,
    downloadStatus: downloadStatus ?? this.downloadStatus,
    extractionStatus: extractionStatus ?? this.extractionStatus,
    filePath: filePath ?? this.filePath,
    fileSize: fileSize ?? this.fileSize,
    sha256: sha256 ?? this.sha256,
    downloadedAt: downloadedAt ?? this.downloadedAt,
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    etag: etag ?? this.etag,
    lastModified: lastModified ?? this.lastModified,
    error: clearError ? '' : error ?? this.error,
    progress: progress ?? this.progress,
    attempts: attempts ?? this.attempts,
    duplicateOf: clearDuplicateOf ? '' : duplicateOf ?? this.duplicateOf,
    extractedPath: extractedPath ?? this.extractedPath,
    extractedAt: extractedAt ?? this.extractedAt,
    pageCount: pageCount ?? this.pageCount,
    sectionCount: sectionCount ?? this.sectionCount,
    ocrPages: ocrPages ?? this.ocrPages,
    warnings: warnings ?? this.warnings,
    downloadedMetadataVersion:
        downloadedMetadataVersion ?? this.downloadedMetadataVersion,
    metadataVersion: metadataVersion ?? this.metadataVersion,
  );

  factory BookLocalState.fromJson(Map<String, dynamic> json) => BookLocalState(
    bookId: _string(json['book_id']) ?? _string(json['bookId']) ?? '',
    downloadStatus: BookDownloadStatus.fromWire(
      json['download_status'] ?? json['downloadStatus'],
    ),
    extractionStatus: BookExtractionStatus.fromWire(
      json['extraction_status'] ?? json['extractionStatus'],
    ),
    filePath: _string(json['file_path']) ?? _string(json['filePath']) ?? '',
    fileSize: _int(json['file_size'] ?? json['fileSize']) ?? 0,
    sha256: _string(json['sha256']) ?? '',
    downloadedAt: _date(json['downloaded_at'] ?? json['downloadedAt']),
    lastCheckedAt: _date(json['last_checked_at'] ?? json['lastCheckedAt']),
    updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
    etag: _string(json['etag']) ?? '',
    lastModified: _string(json['last_modified']) ?? '',
    error: _string(json['error']) ?? '',
    progress: _double(json['progress']) ?? 0,
    attempts: _int(json['attempts']) ?? 0,
    duplicateOf: _string(json['duplicate_of']) ?? '',
    extractedPath:
        _string(json['extracted_path']) ?? _string(json['extractedPath']) ?? '',
    extractedAt: _date(json['extracted_at'] ?? json['extractedAt']),
    pageCount: _int(json['page_count'] ?? json['pageCount']) ?? 0,
    sectionCount: _int(json['section_count'] ?? json['sectionCount']) ?? 0,
    ocrPages: _int(json['ocr_pages']) ?? 0,
    warnings: _strings(json['warnings']),
    downloadedMetadataVersion: _string(json['downloaded_metadata_version']) ?? '',
    metadataVersion: _string(json['metadata_version']) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'book_id': bookId,
    'download_status': downloadStatus.wire,
    'extraction_status': extractionStatus.wire,
    if (filePath.isNotEmpty) 'file_path': filePath,
    if (fileSize > 0) 'file_size': fileSize,
    if (sha256.isNotEmpty) 'sha256': sha256,
    if (downloadedAt != null) 'downloaded_at': downloadedAt!.toIso8601String(),
    if (lastCheckedAt != null)
      'last_checked_at': lastCheckedAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (etag.isNotEmpty) 'etag': etag,
    if (lastModified.isNotEmpty) 'last_modified': lastModified,
    if (error.isNotEmpty) 'error': error,
    if (progress > 0) 'progress': progress,
    if (attempts > 0) 'attempts': attempts,
    if (duplicateOf.isNotEmpty) 'duplicate_of': duplicateOf,
    if (extractedPath.isNotEmpty) 'extracted_path': extractedPath,
    if (extractedAt != null) 'extracted_at': extractedAt!.toIso8601String(),
    if (pageCount > 0) 'page_count': pageCount,
    if (sectionCount > 0) 'section_count': sectionCount,
    if (ocrPages > 0) 'ocr_pages': ocrPages,
    if (warnings.isNotEmpty) 'warnings': warnings,
    if (downloadedMetadataVersion.isNotEmpty)
      'downloaded_metadata_version': downloadedMetadataVersion,
    if (metadataVersion.isNotEmpty) 'metadata_version': metadataVersion,
  };
}

/// The complete read-only catalog.
class OfficialBookCatalog {
  const OfficialBookCatalog({
    required this.version,
    required this.updated,
    required this.books,
    this.schoolYear = '2026-2027',
    this.sources = const [],
    this.notes = '',
  });

  final int version;
  final String updated;
  final String schoolYear;
  final List<OfficialBook> books;
  final List<OfficialSource> sources;
  final String notes;

  bool get isEmpty => books.isEmpty;

  /// Rows for a grade and a subject. The match is language-insensitive and
  /// component-insensitive so `الرياضيات` also finds `الرياضيات باللغة العربية`.
  List<OfficialBook> forGradeSubject(
    String gradeId,
    String subject,
  ) => books
      .where(
        (book) =>
            book.grade == gradeId &&
            book.system == EducationSystem.generalSecondary &&
            subjectMatches(book.subject, subject),
      )
      .toList(growable: false);

  List<OfficialBook> forSystem(
    EducationSystem system, {
    String? grade,
    BaccalaureatePathway? pathway,
  }) => books
      .where(
        (book) =>
            book.system == system &&
            (grade == null || book.grade == grade) &&
            (pathway == null ||
                pathway == BaccalaureatePathway.none ||
                book.track == pathway ||
                book.track == BaccalaureatePathway.none),
      )
      .toList(growable: false);

  List<OfficialBook> forGrade(String gradeId) {
    final rows = books.where((book) => book.grade == gradeId).toList();
    // Notices last so a pathway placeholder never hides a real book.
    rows.sort((a, b) {
      if (a.isNotice != b.isNotice) return a.isNotice ? 1 : -1;
      return a.titleAr.compareTo(b.titleAr);
    });
    return rows;
  }

  List<OfficialBook> search(String query) {
    final term = normalizeArabic(query).toLowerCase().trim();
    if (term.isEmpty) return const [];
    return books.where((book) {
      final haystack = normalizeArabic(
        '${book.titleAr} ${book.subject} ${book.gradeLabel} '
        '${book.pathwayLabel} ${book.fileName}',
      ).toLowerCase();
      return haystack.contains(term);
    }).toList(growable: false);
  }

  /// The grouping keys actually present in the catalog for one grade/system.
  List<String> subjectKeys({
    required String grade,
    EducationSystem? system,
    BaccalaureatePathway? pathway,
  }) {
    final keys = <String>{};
    for (final book in books) {
      if (book.grade != grade) continue;
      if (system != null && book.system != system) continue;
      if (pathway != null &&
          book.track != BaccalaureatePathway.none &&
          book.track != pathway) {
        continue;
      }
      if (book.isNotice) continue;
      keys.add(normalizeSubject(book.subject));
    }
    final list = keys.toList()..sort();
    return list;
  }

  factory OfficialBookCatalog.fromJson(Map<String, dynamic> json) {
    final sourceRows = (json['sources'] as List?) ?? const [];
    return OfficialBookCatalog(
      version: _int(json['version']) ?? 1,
      updated: _string(json['updated']) ?? '',
      schoolYear: _string(json['school_year']) ?? '2026-2027',
      books: ((json['books'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OfficialBook.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      sources: sourceRows
          .whereType<Map>()
          .map((e) => OfficialSource.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      notes: _string(json['notes']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'updated': updated,
    'school_year': schoolYear,
    'notes': notes,
    'sources': sources.map((source) => source.toJson()).toList(),
    'books': books.map((book) => book.toJson()).toList(),
  };
}

/// Grade labels used by the catalog, duplicated here to keep the model
/// Flutter-free and independent from the bundled-library UI.
const Map<String, String> gradeLabels = {
  'sec1': 'الصف الأول الثانوي',
  'sec2': 'الصف الثاني الثانوي',
  'sec3': 'الصف الثالث الثانوي',
};

const Map<String, String> languageLabels = {
  'ar': 'العربية',
  'en': 'الإنجليزية',
  'fr': 'الفرنسية',
  'de': 'الألمانية',
  'es': 'الإسبانية',
  'it': 'الإيطالية',
  'zh': 'الصينية',
};

/// Removes diacritics, tatweel and the Arabic presentation-form noise so
/// search and subject matching behave the same for typed and extracted text.
String normalizeArabic(String value) {
  var text = value
      .replaceAll(RegExp(r'[ً-ْٰـ]'), '')
      .replaceAll(' ', ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

/// Collapses the Ministry's subject variants onto one display group key.
String normalizeSubject(String raw) {
  var text = normalizeArabic(raw);
  if (text.isEmpty) return '';
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Anything after a dash is a component qualifier: story, workbook, grammar.
  text = text.split(RegExp(r'\s*[-–—]\s*')).first.trim();
  // `... باللغة العربية`, `... باللغة الإنجليزية` etc.
  text = text.replaceFirst(RegExp(r'\s+باللغة\s+.*$'), '').trim();
  // `... لغة أجنبية أولى/ثانية` and the older `- قديم` suffix.
  text = text.replaceFirst(RegExp(r'\s+لغة\s+أجنبية.*$'), '').trim();
  text = text.replaceFirst(RegExp(r'\s+قديم$'), '').trim();
  // `اللغة الإنجليزية` and similar are already clean at this point.
  return text;
}

/// Whether two Ministry subject labels belong to the same display group.
bool subjectMatches(String officialSubject, String requestedSubject) {
  final left = normalizeSubject(officialSubject);
  final right = normalizeSubject(requestedSubject);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  // A bundled book may use a short form (`الرياضيات`) while the official row
  // adds a qualifier that survived normalization.
  return left.startsWith(right) || right.startsWith(left);
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}');

double? _double(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? ''}');

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<String> _strings(Object? value) => value is List
    ? value.map((e) => '$e').where((e) => e.isNotEmpty).toList()
    : const [];
