/// Local study-tool artifacts built from one batch PDF.
///
/// Pure Dart: the extractor, the generation engine, the screens and the tests
/// all share these types without a PDF engine or a Flutter binding.
library;

/// Where a background extraction job is.
enum StudyJobState { queued, processing, completed, failed, cancelled }

/// One extraction run for one resource.
///
/// The state is real: a job only reaches [StudyJobState.completed] after the
/// document was written, and [StudyJobState.cancelled] only after the reader
/// stopped between pages.
class StudyJob {
  const StudyJob({
    required this.id,
    required this.resourceId,
    required this.state,
    this.done = 0,
    this.total = 0,
    this.message = '',
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String resourceId;
  final StudyJobState state;

  /// Pages finished so far, and the page count when known.
  final int done;
  final int total;

  /// Arabic progress copy shown next to the bar.
  final String message;

  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isActive =>
      state == StudyJobState.queued || state == StudyJobState.processing;

  double get progress => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);

  StudyJob copyWith({
    StudyJobState? state,
    int? done,
    int? total,
    String? message,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) =>
      StudyJob(
        id: id,
        resourceId: resourceId,
        state: state ?? this.state,
        done: done ?? this.done,
        total: total ?? this.total,
        message: message ?? this.message,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
      );
}

/// One page of a PDF after extraction, or after OCR when it had no text.
class SourcePage {
  const SourcePage({
    required this.pageNumber,
    required this.text,
    this.fromOcr = false,
  });

  /// 1-based page number as the reader displays it.
  final int pageNumber;
  final String text;

  /// True when the text came from OCR and may therefore misread a letter.
  final bool fromOcr;

  Map<String, dynamic> toJson() => {
        'page': pageNumber,
        'text': text,
        if (fromOcr) 'ocr': true,
      };

  factory SourcePage.fromJson(Map<String, dynamic> json) => SourcePage(
        pageNumber: (json['page'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        fromOcr: json['ocr'] == true,
      );
}

/// Everything the local study tools may cite for one batch PDF.
class SourceDocument {
  const SourceDocument({
    required this.resourceId,
    required this.batchId,
    required this.title,
    required this.sha256,
    required this.pages,
    required this.warnings,
    required this.extractedAt,
    this.pageCount = 0,
    this.ocrPageCount = 0,
    this.fromCache = false,
  });

  final String resourceId;
  final String batchId;
  final String title;

  /// The SHA-256 of the file this text came from. A changed file never reuses
  /// the old cache entry.
  final String sha256;

  final List<SourcePage> pages;

  /// Honest extraction notes: OCR caps, unreadable pages, no text at all.
  final List<String> warnings;

  final DateTime extractedAt;
  final int pageCount;
  final int ocrPageCount;

  /// True when the document came from the `text/<sha16>.json` cache.
  final bool fromCache;

  /// A page is usable when it has enough text to build a sentence from.
  static const int minimumPageText = 24;

  SourcePage? page(int pageNumber) {
    for (final page in pages) {
      if (page.pageNumber == pageNumber) return page;
    }
    return null;
  }

  String pageText(int pageNumber) => page(pageNumber)?.text ?? '';

  /// Pages with enough text for the study tools.
  List<SourcePage> get usablePages => [
        for (final page in pages)
          if (page.text.trim().length >= minimumPageText) page,
      ];

  bool get hasUsableText => usablePages.isNotEmpty;

  int get usablePageCount => usablePages.length;

  SourceDocument copyWith({bool? fromCache}) => SourceDocument(
        resourceId: resourceId,
        batchId: batchId,
        title: title,
        sha256: sha256,
        pages: pages,
        warnings: warnings,
        extractedAt: extractedAt,
        pageCount: pageCount,
        ocrPageCount: ocrPageCount,
        fromCache: fromCache ?? this.fromCache,
      );

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'resource_id': resourceId,
        'batch_id': batchId,
        'title': title,
        'sha256': sha256,
        'extracted_at': extractedAt.toIso8601String(),
        'page_count': pageCount,
        'ocr_pages': ocrPageCount,
        'warnings': warnings,
        'pages': pages.map((page) => page.toJson()).toList(),
      };

  factory SourceDocument.fromJson(Map<String, dynamic> json) => SourceDocument(
        resourceId: json['resource_id'] as String? ?? '',
        batchId: json['batch_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
        pages: ((json['pages'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SourcePage.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
        warnings: ((json['warnings'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(growable: false),
        extractedAt: DateTime.tryParse(json['extracted_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
        ocrPageCount: (json['ocr_pages'] as num?)?.toInt() ?? 0,
      );
}

/// The kinds of question the local generator can build from source sentences.
enum StudyQuestionKind { multipleChoice, cloze, trueFalse }

/// One question that quotes the page it came from.
class StudyQuestion {
  const StudyQuestion({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.page,
    required this.evidence,
    required this.explanation,
    this.difficulty = 'medium',
  });

  final String id;
  final StudyQuestionKind kind;
  final String prompt;
  final List<String> choices;
  final int correctIndex;

  /// The 1-based page the evidence was found on.
  final int page;

  /// A verbatim excerpt from that page.
  final String evidence;

  final String explanation;
  final String difficulty;

  /// The answer text, or an empty string when the index is invalid.
  String get correctChoice => correctIndex >= 0 && correctIndex < choices.length
      ? choices[correctIndex]
      : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'prompt': prompt,
        'choices': choices,
        'correct': correctIndex,
        'page': page,
        'evidence': evidence,
        'explanation': explanation,
        'difficulty': difficulty,
      };

  factory StudyQuestion.fromJson(Map<String, dynamic> json) => StudyQuestion(
        id: json['id'] as String? ?? '',
        kind: StudyQuestionKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => StudyQuestionKind.multipleChoice,
        ),
        prompt: json['prompt'] as String? ?? '',
        choices: ((json['choices'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(growable: false),
        correctIndex: (json['correct'] as num?)?.toInt() ?? -1,
        page: (json['page'] as num?)?.toInt() ?? 0,
        evidence: json['evidence'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        difficulty: json['difficulty'] as String? ?? 'medium',
      );
}

/// One submitted interactive-test attempt, stored on this device only.
class StudyAttempt {
  const StudyAttempt({
    required this.resourceId,
    required this.answers,
    required this.correct,
    required this.total,
    required this.submittedAt,
  });

  final String resourceId;

  /// Question id → chosen choice index. Unanswered questions are absent.
  final Map<String, int> answers;

  final int correct;
  final int total;
  final DateTime submittedAt;

  double get score => total <= 0 ? 0 : correct / total;

  Map<String, dynamic> toJson() => {
        'resource_id': resourceId,
        'answers': answers,
        'correct': correct,
        'total': total,
        'submitted_at': submittedAt.toIso8601String(),
      };

  factory StudyAttempt.fromJson(Map<String, dynamic> json) => StudyAttempt(
        resourceId: json['resource_id'] as String? ?? '',
        answers: ((json['answers'] as Map?) ?? const {}).map(
          (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? -1),
        ),
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        submittedAt: DateTime.tryParse(json['submitted_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// What kind of fact the information bank extracted.
enum StudyFactKind { definition, date, number, step }

/// One extracted fact with its page and the sentence it came from.
class StudyFact {
  const StudyFact({
    required this.id,
    required this.kind,
    required this.text,
    required this.page,
    required this.excerpt,
    this.term = '',
  });

  final String id;
  final StudyFactKind kind;

  /// The fact itself, quoted from the page.
  final String text;

  final int page;

  /// The surrounding sentence, verbatim, used as evidence.
  final String excerpt;

  /// The term a definition belongs to; empty for other kinds.
  final String term;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'page': page,
        'excerpt': excerpt,
        if (term.isNotEmpty) 'term': term,
      };

  factory StudyFact.fromJson(Map<String, dynamic> json) => StudyFact(
        id: json['id'] as String? ?? '',
        kind: StudyFactKind.values.firstWhere(
          (kind) => kind.name == json['kind'],
          orElse: () => StudyFactKind.definition,
        ),
        text: json['text'] as String? ?? '',
        page: (json['page'] as num?)?.toInt() ?? 0,
        excerpt: json['excerpt'] as String? ?? '',
        term: json['term'] as String? ?? '',
      );
}

/// The facts extracted from one document, in page order.
class StudyBank {
  const StudyBank({required this.resourceId, required this.facts});

  final String resourceId;
  final List<StudyFact> facts;

  bool get isEmpty => facts.isEmpty;

  /// Local substring search over the fact text and term.
  ///
  /// Matching is done by the caller through [EvidenceValidator.normalize] so
  /// Arabic letter variants and diacritics do not hide a fact.
  List<StudyFact> matching(String Function(String) normalize, String query) {
    final needle = normalize(query);
    if (needle.isEmpty) return facts;
    return [
      for (final fact in facts)
        if (normalize('${fact.term} ${fact.text} ${fact.excerpt}').contains(
          needle,
        ))
          fact,
    ];
  }
}

/// One node of the local mind map. [page] is null for grouping nodes.
class StudyMapNode {
  const StudyMapNode({
    required this.id,
    required this.label,
    this.note = '',
    this.page,
    this.children = const [],
  });

  final String id;
  final String label;
  final String note;
  final int? page;
  final List<StudyMapNode> children;
}

/// A heading/term hierarchy with page references.
class StudyMindMap {
  const StudyMindMap({
    required this.resourceId,
    required this.title,
    required this.root,
  });

  final String resourceId;
  final String title;
  final StudyMapNode root;

  /// The screen-reader alternative: one indented line per node, with the page
  /// where the node is grounded.
  List<String> get outline {
    final lines = <String>[];
    void walk(StudyMapNode node, int depth) {
      final page = node.page == null ? '' : ' — صفحة ${node.page}';
      lines.add('${'  ' * depth}${node.label}$page');
      for (final child in node.children) {
        walk(child, depth + 1);
      }
    }

    walk(root, 0);
    return lines;
  }
}
