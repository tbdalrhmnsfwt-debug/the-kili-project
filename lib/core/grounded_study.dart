/// Source-grounded study artifacts for official books.
///
/// Every artifact here is built from text that was actually extracted from the
/// downloaded PDF, and every fact carries the page it came from. The local
/// generators are extractive on purpose: they quote and reorganise the book
/// instead of inventing explanations. The optional AI explanation is labelled
/// as supplemental and is never used when the backend is unavailable.
library;

import 'dart:math';

import '../models/ai.dart';
import '../models/exam.dart';
import '../models/official_book.dart';
import '../models/recall.dart';
import 'ai_service.dart';
import 'book_extraction.dart';
import 'vocabulary.dart';

/// One page's text within a section.
class PassagePage {
  const PassagePage({required this.pageNumber, required this.text, this.fromOcr = false});

  final int pageNumber;
  final String text;
  final bool fromOcr;
}

/// A section of an official book together with its provenance.
class OfficialPassage {
  OfficialPassage({
    required this.book,
    required this.section,
    required this.extraction,
  });

  final OfficialBook book;
  final ExtractedSection section;
  final ExtractedBook extraction;

  int get startPage => section.startPage;
  int get endPage => section.endPage;

  String get edition => book.metadataVersion;

  /// The catalog version captured when the text was extracted. When it differs
  /// from the current row, the UI warns that generated notes may be stale.
  bool get isCurrentEdition {
    final snapshot = extraction.catalogSnapshot['metadata_version'];
    if (snapshot == null || '${snapshot}'.isEmpty) return true;
    return '${snapshot}' == book.metadataVersion;
  }

  List<PassagePage> get pages => [
    for (final page in extraction.pages)
      if (page.pageNumber >= startPage && page.pageNumber <= endPage)
        PassagePage(
          pageNumber: page.pageNumber,
          text: page.text,
          fromOcr: page.fromOcr,
        ),
  ];

  String get citationLabel => startPage == endPage
      ? 'صفحة $startPage'
      : 'صفحات $startPage–$endPage';

  /// The text with page markers, used as AI context.
  String get markedText {
    final buffer = StringBuffer();
    for (final page in pages) {
      if (page.text.trim().isEmpty) continue;
      buffer.writeln('[صفحة ${page.pageNumber}]');
      buffer.writeln(page.text.trim());
      buffer.writeln();
    }
    return buffer.toString();
  }
}

/// A page citation attached to a generated note.
class StudyCitation {
  const StudyCitation({required this.page, required this.quote});

  final int page;
  final String quote;

  String get label => 'صفحة $page';
}

/// What kind of artifact a note is.
enum StudyNoteKind {
  explanation,
  summary,
  terms,
  formulas,
  steps,
  vocabulary,
  revision,
}

/// A generated note with its edition and generation time.
class StudyNote {
  const StudyNote({
    required this.title,
    required this.body,
    required this.kind,
    required this.citations,
    required this.generatedAt,
    required this.edition,
    this.isAi = false,
    this.warning = '',
  });

  final String title;
  final String body;
  final StudyNoteKind kind;
  final List<StudyCitation> citations;
  final DateTime generatedAt;
  final String edition;
  final bool isAi;
  final String warning;

  String get label => switch (kind) {
    StudyNoteKind.explanation => isAi ? 'شرح مساعد بالذكاء الاصطناعي' : 'شرح محلي من الكتاب',
    StudyNoteKind.summary => 'ملخص من نص الكتاب',
    StudyNoteKind.terms => 'تعريفات ومصطلحات',
    StudyNoteKind.formulas => 'قوانين ومعادلات',
    StudyNoteKind.steps => 'خطوات كما وردت في الكتاب',
    StudyNoteKind.vocabulary => 'مفردات وترجمة من قاموس التطبيق',
    StudyNoteKind.revision => 'ورقة مراجعة سريعة',
  };
}

/// Generates explanations, summaries, cards, maps and quizzes from official
/// extracted sections.
class GroundedStudyService {
  GroundedStudyService({AiService? ai}) : _ai = ai;

  final AiService? _ai;

  static final RegExp _sentenceEnd = RegExp(r'(?<=[.!؟?])\s+|\n+');
  static const int _maxAiContext = 16000;

  // ------------------------------------------------------------ explanation

  /// An AI explanation when the backend works, otherwise a local one.
  Future<StudyNote> explanation(OfficialPassage passage) async {
    final aiText = await _aiExplanation(passage);
    if (aiText != null && aiText.trim().isNotEmpty) {
      return StudyNote(
        title: 'شرح «${passage.section.title}»',
        body: aiText.trim(),
        kind: StudyNoteKind.explanation,
        citations: _citationsFromPages(passage),
        generatedAt: DateTime.now(),
        edition: passage.edition,
        isAi: true,
        warning:
            'الشرح ده مساعد بالذكاء الاصطناعي واتبنى على نص الصفحات المرفقة. '
            'اتأكد من الصفحات المصدر قبل الاعتماد عليه.',
      );
    }
    return localExplanation(passage);
  }

  Future<String?> _aiExplanation(OfficialPassage passage) async {
    final ai = _ai;
    if (ai == null) return null;
    final context = passage.markedText;
    if (context.trim().isEmpty) return null;
    final trimmed = context.length > _maxAiContext
        ? context.substring(0, _maxAiContext)
        : context;
    return ai.askGrounded(
      question:
          'اشرح الدرس التالي لطالب مصري في الثانوية بالعربي المبسط. '
          'استخدم المعلومات الموجودة في النص فقط، وماتضيفش حقائق من بره. '
          'اذكر رقم الصفحة بين قوسين زي [صفحة 12] بعد كل معلومة. '
          'الدرس: «${passage.section.title}».',
      context: trimmed,
      subject: passage.book.subject,
      pageStart: passage.startPage,
      pageEnd: passage.endPage,
    );
  }

  /// A local, extractive explanation. The wording is ours; the facts and
  /// examples are quoted from the book with page numbers.
  StudyNote localExplanation(OfficialPassage passage) {
    final sentences = _sentences(passage);
    final terms = _terms(passage);
    final formulas = _formulas(passage);
    final steps = _steps(passage);
    final buffer = StringBuffer();
    buffer.writeln(
      'الفكرة العامة للدرس موجودة في ${passage.citationLabel} من '
      '«${passage.book.titleAr}». النقاط اللي تحت كلها مأخوذة من نص الكتاب '
      'ومن غير إضافة معلومات من بره.',
    );
    buffer.writeln();

    if (terms.isNotEmpty) {
      buffer.writeln('**مصطلحات أساسية**');
      for (final term in terms.take(6)) {
        buffer.writeln(
          '• **${term.term}**: ${_ellipsis(term.definition, 220)} '
          '_[صفحة ${term.page}]_',
        );
      }
      buffer.writeln();
    }

    final key = _pickSentences(sentences, 6);
    if (key.isNotEmpty) {
      buffer.writeln('**أهم الأفكار من النص**');
      for (final sentence in key) {
        buffer.writeln('• ${_ellipsis(sentence.text, 260)} _[صفحة ${sentence.page}]_');
      }
      buffer.writeln();
    }

    if (formulas.isNotEmpty) {
      buffer.writeln('**قوانين وردت في الدرس**');
      for (final formula in formulas.take(4)) {
        buffer.writeln('• `$formula` _[صفحة ${formula.page}]_');
      }
      buffer.writeln();
    }

    if (steps.isNotEmpty) {
      buffer.writeln('**خطوات مرتبة كما وردت**');
      for (final step in steps.take(6)) {
        buffer.writeln('• ${_ellipsis(step.text, 220)} _[صفحة ${step.page}]_');
      }
    }

    if (sentences.isEmpty) {
      buffer.writeln(
        'الصفحات دي مفيهاش نص كفاية لبناء شرح. جرّب تشغيل الاستخراج تاني '
        'أو راجع الصفحة المصدر بنفسك.',
      );
    }
    return StudyNote(
      title: 'شرح «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.explanation,
      citations: _citationsFromPages(passage),
      generatedAt: DateTime.now(),
      edition: passage.edition,
      warning: passage.isCurrentEdition
          ? 'الشرح محلي ومبني على النص المستخرج. راجع الصفحات المذكورة.'
          : 'نسخة الكتاب اتغيرت بعد الاستخراج. أعد الاستخراج قبل الاعتماد '
                'على الشرح.',
    );
  }

  // ---------------------------------------------------------------- summary

  StudyNote summary(OfficialPassage passage) {
    final sentences = _sentences(passage);
    final picked = _pickSentences(sentences, 8);
    final buffer = StringBuffer();
    if (picked.isEmpty) {
      buffer.writeln('مفيش نص كفاية لعمل ملخص من الصفحات دي.');
    } else {
      for (final sentence in picked) {
        buffer.writeln('• ${_ellipsis(sentence.text, 280)} _[صفحة ${sentence.page}]_');
      }
    }
    return StudyNote(
      title: 'ملخص «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.summary,
      citations: [
        for (final sentence in picked)
          StudyCitation(page: sentence.page, quote: sentence.text),
      ],
      generatedAt: DateTime.now(),
      edition: passage.edition,
      warning:
          'الملخص ده استخراجي: بيختار جمل من الكتاب نفسه ويحافظ على ترتيبها. '
          'مش بيضيف معلومات جديدة.',
    );
  }

  // --------------------------------------------------------------- revision

  /// A one-page revision sheet assembled from the same extractive pieces as
  /// the other notes. Every line keeps its page number; the self-test
  /// questions are built only from terms the book actually defines.
  StudyNote revisionNote(OfficialPassage passage) {
    final key = _pickSentences(_sentences(passage), 5);
    final terms = _terms(passage);
    final formulas = _formulas(passage);
    final steps = _steps(passage);
    final buffer = StringBuffer();
    buffer.writeln(
      'مراجعة سريعة لـ «${passage.section.title}» من '
      '${passage.citationLabel} — «${passage.book.titleAr}».',
    );
    buffer.writeln();

    if (key.isNotEmpty) {
      buffer.writeln('**أهم النقاط**');
      for (final sentence in key) {
        buffer.writeln(
          '• ${_ellipsis(sentence.text, 220)} _[صفحة ${sentence.page}]_',
        );
      }
      buffer.writeln();
    }

    if (terms.isNotEmpty) {
      buffer.writeln('**تعريفات لازم تفتكرها**');
      for (final term in terms.take(6)) {
        buffer.writeln(
          '• **${term.term}** — ${_ellipsis(term.definition, 200)} '
          '_[صفحة ${term.page}]_',
        );
      }
      buffer.writeln();
    }

    if (formulas.isNotEmpty) {
      buffer.writeln('**قوانين**');
      for (final formula in formulas.take(4)) {
        buffer.writeln('• `$formula` _[صفحة ${formula.page}]_');
      }
      buffer.writeln();
    }

    if (steps.isNotEmpty) {
      buffer.writeln('**خطوات**');
      for (final step in steps.take(4)) {
        buffer.writeln('• ${_ellipsis(step.text, 200)} _[صفحة ${step.page}]_');
      }
      buffer.writeln();
    }

    if (terms.isNotEmpty) {
      buffer.writeln('**اختبر نفسك**');
      for (var i = 0; i < terms.take(8).length; i++) {
        buffer.writeln(
          '${i + 1}. إيه المقصود بـ «${terms[i].term}»؟ '
          '_[صفحة ${terms[i].page}]_',
        );
      }
    }

    if (key.isEmpty && terms.isEmpty && formulas.isEmpty && steps.isEmpty) {
      buffer.writeln(
        'مفيش نص كفاية لعمل ورقة مراجعة من الصفحات دي. '
        'راجع الصفحة المصدر بنفسك.',
      );
    }

    return StudyNote(
      title: 'مراجعة «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.revision,
      citations: [
        for (final sentence in key)
          StudyCitation(page: sentence.page, quote: sentence.text),
        for (final term in terms.take(6))
          StudyCitation(page: term.page, quote: term.definition),
        for (final formula in formulas.take(4))
          StudyCitation(page: formula.page, quote: formula.text),
      ],
      generatedAt: DateTime.now(),
      edition: passage.edition,
      warning:
          'ورقة المراجعة دي تجميع من نص الكتاب نفسه وأسئلة على تعريفاته. '
          'مفيش فيها معلومة من برّه الكتاب.',
    );
  }

  // ------------------------------------------------------------------ terms

  StudyNote definitionsNote(OfficialPassage passage) {
    final terms = _terms(passage);
    final buffer = StringBuffer();
    for (final term in terms.take(12)) {
      buffer.writeln('• **${term.term}** — ${term.definition} _[صفحة ${term.page}]_');
    }
    if (terms.isEmpty) {
      buffer.writeln(
        'معرفناش نلاقي تعريفات بصيغة واضحة في الصفحات دي. '
        'افتح النص الأصلي من التبويب اللي فوق.',
      );
    }
    return StudyNote(
      title: 'تعريفات «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.terms,
      citations: [
        for (final term in terms.take(12))
          StudyCitation(page: term.page, quote: term.definition),
      ],
      generatedAt: DateTime.now(),
      edition: passage.edition,
    );
  }

  StudyNote formulasNote(OfficialPassage passage) {
    final formulas = _formulas(passage);
    final buffer = StringBuffer();
    for (final formula in formulas.take(12)) {
      buffer.writeln('• `$formula` _[صفحة ${formula.page}]_');
    }
    if (formulas.isEmpty) {
      buffer.writeln('مفيش قوانين أو معادلات واضحة في الصفحات دي.');
    }
    return StudyNote(
      title: 'قوانين «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.formulas,
      citations: [
        for (final formula in formulas.take(12))
          StudyCitation(page: formula.page, quote: formula.text),
      ],
      generatedAt: DateTime.now(),
      edition: passage.edition,
    );
  }

  StudyNote stepsNote(OfficialPassage passage) {
    final steps = _steps(passage);
    final buffer = StringBuffer();
    for (final step in steps.take(12)) {
      buffer.writeln('• ${step.text} _[صفحة ${step.page}]_');
    }
    if (steps.isEmpty) {
      buffer.writeln(
        'معرفناش نلاقي خطوات مرقّمة أو مرتبة في الصفحات دي. '
        'ممكن الخطوات تكون جزء من شرح عادي في الكتاب.',
      );
    }
    return StudyNote(
      title: 'خطوات «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.steps,
      citations: [
        for (final step in steps.take(12))
          StudyCitation(page: step.page, quote: step.text),
      ],
      generatedAt: DateTime.now(),
      edition: passage.edition,
    );
  }

  // ------------------------------------------------------------ vocabulary

  /// English words from the lesson glossed with the app's bundled dictionary.
  ///
  /// Returns `null` when the lesson has no word the dictionary can translate,
  /// so the UI hides the section instead of showing an empty card.
  StudyNote? vocabularyNote(
    OfficialPassage passage,
    Map<String, String> translations,
  ) {
    final items = extractVocabulary(
      pages: [
        for (final page in passage.pages)
          VocabularyPage(pageNumber: page.pageNumber, text: page.text),
      ],
      translations: translations,
    );
    if (items.isEmpty) return null;
    final buffer = StringBuffer();
    for (final item in items) {
      buffer.writeln(
        '• **${item.term}** — ${item.translation} '
        '_[صفحة ${item.page}]_',
      );
      if (item.context.isNotEmpty) {
        buffer.writeln('  _${_ellipsis(item.context, 160)}_');
      }
      buffer.writeln();
    }
    return StudyNote(
      title: 'مفردات «${passage.section.title}»',
      body: buffer.toString().trim(),
      kind: StudyNoteKind.vocabulary,
      citations: [
        for (final item in items)
          StudyCitation(page: item.page, quote: item.context),
      ],
      generatedAt: DateTime.now(),
      edition: passage.edition,
      warning:
          'الترجمات من قاموس التطبيق المضمّن، والكلمات نفسها مأخوذة من نص '
          'الدرس. مش كل كلمة في الكتاب موجودة في القاموس.',
    );
  }

  // ------------------------------------------------------------- flashcards

  /// Builds reveal-before-answer cards. Every card cites a page.
  List<RecallCard> flashcards(OfficialPassage passage, {int limit = 14}) {
    final cards = <RecallCard>[];
    final terms = _terms(passage);
    final sentences = _sentences(passage);
    var index = 0;

    for (final term in terms) {
      if (cards.length >= limit) break;
      final id = _cardId(passage, 't${index++}');
      cards.add(
        RecallCard(
          id: id,
          kind: CardKind.swipe,
          front: CardFace(
            text: 'ما المقصود بـ «${term.term}»؟',
            hint: 'جاوب قبل ما تقلب الكارت.',
          ),
          back: CardFace(text: term.definition),
          lessonId: '${passage.book.id}/${passage.section.id}',
          bookId: passage.book.id,
          createdAt: DateTime.now(),
          sourcePage: term.page,
          sourceSectionId: passage.section.id,
          sourceBookTitle: passage.book.titleAr,
        ),
      );
    }

    for (final sentence in sentences) {
      if (cards.length >= limit) break;
      final term = _termInSentence(sentence.text, terms);
      if (term == null) continue;
      final blanked = sentence.text.replaceFirst(term.term, '________');
      final id = _cardId(passage, 'c${index++}');
      cards.add(
        RecallCard(
          id: id,
          kind: CardKind.fillBlank,
          front: CardFace(text: blanked, hint: 'أكمل الفراغ'),
          back: CardFace(text: term.term, hint: sentence.text),
          lessonId: '${passage.book.id}/${passage.section.id}',
          bookId: passage.book.id,
          createdAt: DateTime.now(),
          sourcePage: sentence.page,
          sourceSectionId: passage.section.id,
          sourceBookTitle: passage.book.titleAr,
        ),
      );
    }

    if (cards.isEmpty && sentences.isNotEmpty) {
      final sentence = sentences.first;
      cards.add(
        RecallCard(
          id: _cardId(passage, 's0'),
          kind: CardKind.swipe,
          front: const CardFace(
            text: 'استرجع الفكرة الأساسية في الدرس من غير ما تبص.',
            hint: 'اكتب الفكرة في دماغك الأول.',
          ),
          back: CardFace(text: sentence.text),
          lessonId: '${passage.book.id}/${passage.section.id}',
          bookId: passage.book.id,
          createdAt: DateTime.now(),
          sourcePage: sentence.page,
          sourceSectionId: passage.section.id,
          sourceBookTitle: passage.book.titleAr,
        ),
      );
    }
    return cards;
  }

  // ------------------------------------------------------------------ quiz

  /// Builds MCQ, true/false and short-answer questions from the passage.
  List<ExamQuestion> quiz(OfficialPassage passage, {int limit = 10}) {
    final questions = <ExamQuestion>[];
    final terms = _terms(passage);
    final sentences = _sentences(passage);
    final steps = _steps(passage);
    var counter = 0;

    ExamQuestion build({
      required String prompt,
      required AnswerKind kind,
      List<String> options = const [],
      int? correctIndex,
      String explanation = '',
      String modelAnswer = '',
      int? page,
      String difficulty = 'medium',
    }) {
      counter++;
      return ExamQuestion(
        id: '${passage.book.id}-${passage.section.id}-q$counter',
        prompt: prompt,
        answerKind: kind,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
        modelAnswer: modelAnswer,
        difficulty: difficulty,
        source: 'official_local',
        sourcePage: page,
        sourcePageEnd: page == passage.endPage ? passage.endPage : page,
        sourceBookId: passage.book.id,
        sourceBookTitle: passage.book.titleAr,
        sourceSectionId: passage.section.id,
        sourceSectionTitle: passage.section.title,
      );
    }

    // Definition questions need at least two other definitions as options.
    if (terms.length >= 3) {
      final random = Random(passage.section.id.hashCode);
      for (final term in terms.take(4)) {
        if (questions.length >= limit) break;
        final distractors = terms
            .where((other) => other.term != term.term)
            .map((other) => other.definition)
            .toSet()
            .toList()
          ..shuffle(random);
        final options = [term.definition, ...distractors.take(3)];
        options.shuffle(random);
        questions.add(
          build(
            prompt: 'أي تعريف يطابق «${term.term}»؟',
            kind: AnswerKind.multipleChoice,
            options: options,
            correctIndex: options.indexOf(term.definition),
            explanation:
                'التعريف الصحيح مذكور في صفحة ${term.page}: ${term.definition}',
            modelAnswer: term.definition,
            page: term.page,
            difficulty: 'easy',
          ),
        );
      }
    }

    // Cloze questions.
    if (terms.length >= 2) {
      final random = Random('${passage.section.id}:cloze'.hashCode);
      for (final sentence in sentences) {
        if (questions.length >= limit) break;
        if (sentence.text.length < 40 || sentence.text.length > 240) continue;
        final term = _termInSentence(sentence.text, terms);
        if (term == null) continue;
        final options = [
          term.term,
          ...terms
              .where((other) => other.term != term.term)
              .map((other) => other.term)
              .toSet()
              .take(3),
        ]..shuffle(random);
        if (options.length < 3) continue;
        questions.add(
          build(
            prompt: sentence.text.replaceFirst(term.term, '________'),
            kind: AnswerKind.multipleChoice,
            options: options,
            correctIndex: options.indexOf(term.term),
            explanation:
                'النص الأصلي في صفحة ${sentence.page}: ${sentence.text}',
            modelAnswer: term.term,
            page: sentence.page,
          ),
        );
      }
    }

    // True/false: a verbatim sentence (true) or the same sentence with a term
    // swapped for another term from the book (false).
    if (terms.length >= 2 && sentences.isNotEmpty) {
      final random = Random('${passage.section.id}:tf'.hashCode);
      for (final sentence in sentences.take(6)) {
        if (questions.length >= limit) break;
        final term = _termInSentence(sentence.text, terms);
        if (term == null || sentence.text.length > 220) continue;
        final shouldBeTrue = random.nextBool();
        String statement = sentence.text;
        if (!shouldBeTrue) {
          final other = terms
              .firstWhere(
                (candidate) => candidate.term != term.term,
                orElse: () => term,
              )
              .term;
          if (other == term.term) continue;
          statement = sentence.text.replaceFirst(term.term, other);
        }
        questions.add(
          build(
            prompt: statement,
            kind: AnswerKind.multipleChoice,
            options: const ['صح', 'خطأ'],
            correctIndex: shouldBeTrue ? 0 : 1,
            explanation:
                'النص في صفحة ${sentence.page}: ${sentence.text}',
            modelAnswer: shouldBeTrue ? 'صح' : 'خطأ',
            page: sentence.page,
          ),
        );
      }
    }

    // Short-answer questions quote the model answer; grading uses keyword
    // overlap with that quote.
    if (terms.isNotEmpty) {
      for (final term in terms.take(3)) {
        if (questions.length >= limit) break;
        questions.add(
          build(
            prompt: 'اشرح بإيجاز معنى «${term.term}» بأسلوبك.',
            kind: AnswerKind.freeText,
            explanation:
                'الإجابة النموذجية من صفحة ${term.page}: ${term.definition}',
            modelAnswer: term.definition,
            page: term.page,
            difficulty: 'hard',
          ),
        );
      }
    }

    // Step questions are only generated when the book itself lists steps.
    if (steps.isNotEmpty && questions.length < limit) {
      final step = steps.first;
      questions.add(
        build(
          prompt: 'اذكر الخطوات الأساسية المذكورة في الدرس.',
          kind: AnswerKind.freeText,
          explanation: 'الخطوات كما وردت في صفحة ${step.page}: ${step.text}',
          modelAnswer: steps.map((entry) => entry.text).join(' '),
          page: step.page,
          difficulty: 'hard',
        ),
      );
    }

    questions.shuffle(Random(passage.section.id.hashCode));
    return questions.take(limit).toList(growable: false);
  }

  // -------------------------------------------------------------- mind map

  /// A structured outline. The screen renders it as an interactive graph and
  /// offers the outline as the accessible fallback.
  MindMap mindMap(OfficialPassage passage) {
    final terms = _terms(passage);
    final formulas = _formulas(passage);
    final steps = _steps(passage);
    final sentences = _sentences(passage);
    final children = <MapNode>[];

    if (terms.isNotEmpty) {
      children.add(
        MapNode(
          id: 'terms',
          label: 'المفاهيم والتعريفات',
          note: 'من صفحات ${passage.startPage}–${passage.endPage}',
          children: [
            for (var i = 0; i < terms.take(5).length; i++)
              MapNode(
                id: 'term$i',
                label: terms[i].term,
                note: 'صفحة ${terms[i].page}: ${_ellipsis(terms[i].definition, 140)}',
              ),
          ],
        ),
      );
    }
    if (formulas.isNotEmpty) {
      children.add(
        MapNode(
          id: 'formulas',
          label: 'قوانين ومعادلات',
          children: [
            for (var i = 0; i < formulas.take(4).length; i++)
              MapNode(
                id: 'formula$i',
                label: formulas[i].text,
                note: 'صفحة ${formulas[i].page}',
              ),
          ],
        ),
      );
    }
    if (steps.isNotEmpty) {
      children.add(
        MapNode(
          id: 'steps',
          label: 'خطوات مرتبة',
          children: [
            for (var i = 0; i < steps.take(5).length; i++)
              MapNode(
                id: 'step$i',
                label: _ellipsis(steps[i].text, 80),
                note: 'صفحة ${steps[i].page}',
              ),
          ],
        ),
      );
    }
    final key = _pickSentences(sentences, 5);
    if (key.isNotEmpty) {
      children.add(
        MapNode(
          id: 'ideas',
          label: 'أفكار رئيسية',
          children: [
            for (var i = 0; i < key.length; i++)
              MapNode(
                id: 'idea$i',
                label: _ellipsis(key[i].text, 90),
                note: 'صفحة ${key[i].page}',
              ),
          ],
        ),
      );
    }
    if (children.isEmpty) {
      children.add(
        const MapNode(
          id: 'empty',
          label: 'مفيش نص كفاية لبناء خريطة',
          note: 'راجع الصفحات المصدر',
        ),
      );
    }
    return MindMap(
      id: 'official-${passage.book.id}-${passage.section.id}',
      title: passage.section.title,
      style: MapStyle.mindmap,
      createdAt: DateTime.now(),
      root: MapNode(
        id: 'root',
        label: passage.section.title,
        note:
            '${passage.book.titleAr} · ${passage.citationLabel} · '
            '${passage.book.system.label}',
        children: children,
      ),
    );
  }

  // -------------------------------------------------------------- internals

  List<_Sentence> _sentences(OfficialPassage passage) {
    final sentences = <_Sentence>[];
    for (final page in passage.pages) {
      for (final raw in page.text.split(_sentenceEnd)) {
        final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.length < 25 || text.length > 500) continue;
        if (RegExp(r'^\d+$').hasMatch(text)) continue;
        sentences.add(_Sentence(text, page.pageNumber));
      }
    }
    return sentences;
  }

  List<_Term> _terms(OfficialPassage passage) {
    final seen = <String>{};
    final terms = <_Term>[];
    final colon = RegExp(r'^(.{2,45}?)\s*[:：]\s*(.{10,})$');
    final copula = RegExp(r'^(.{2,45}?)\s+(?:هو|هى|هي)\s+(.{10,})$');
    for (final page in passage.pages) {
      for (final raw in page.text.split(RegExp(r'[\n\r]+'))) {
        final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.length < 15 || line.length > 420) continue;
        final match = colon.firstMatch(line) ?? copula.firstMatch(line);
        if (match == null) continue;
        var term = match.group(1)!.trim();
        final definition = match.group(2)!.trim();
        term = term.replaceAll(RegExp(r'^[-•*\d.)\s]+'), '').trim();
        if (term.isEmpty || term.split(RegExp(r'\s+')).length > 6) continue;
        if (definition.split(RegExp(r'\s+')).length < 2) continue;
        final key = normalizeArabic(term);
        if (!seen.add(key)) continue;
        terms.add(_Term(term, definition, page.pageNumber));
        if (terms.length >= 40) return terms;
      }
    }
    return terms;
  }

  List<_Formula> _formulas(OfficialPassage passage) {
    final formulas = <_Formula>[];
    final formulaPattern = RegExp(
      r'[=＝]|[×÷√∑π]|(?:^|\s)(?:sin|cos|tan|log|ln)\s*\(',
    );
    for (final page in passage.pages) {
      for (final raw in page.text.split(RegExp(r'[\n\r]+'))) {
        final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.length < 5 || line.length > 180) continue;
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(line)) continue;
        if (!formulaPattern.hasMatch(line)) continue;
        if (line.split(' ').length > 30) continue;
        formulas.add(_Formula(line, page.pageNumber));
        if (formulas.length >= 20) return formulas;
      }
    }
    return formulas;
  }

  List<_Step> _steps(OfficialPassage passage) {
    final steps = <_Step>[];
    final patterns = [
      RegExp(r'^(أولًا|أولا|ثانيًا|ثانيا|ثالثًا|ثالثا|رابعًا|رابعا|خامسًا|خامسا)[\s:：-]'),
      RegExp(r'^(?:الخطوة|خطوة)\s*[\d٠-٩]+'),
      RegExp(r'^[\d٠-٩]+\s*[-.)]\s+'),
    ];
    for (final page in passage.pages) {
      for (final raw in page.text.split(RegExp(r'[\n\r]+'))) {
        final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.length < 12 || line.length > 300) continue;
        if (!patterns.any((pattern) => pattern.hasMatch(line))) continue;
        steps.add(_Step(line, page.pageNumber));
        if (steps.length >= 20) return steps;
      }
    }
    return steps;
  }

  List<_Sentence> _pickSentences(List<_Sentence> sentences, int count) {
    if (sentences.length <= count) return sentences;
    final frequency = <String, int>{};
    for (final sentence in sentences) {
      for (final word in _words(sentence.text)) {
        frequency[word] = (frequency[word] ?? 0) + 1;
      }
    }
    final scored = <({int index, _Sentence sentence, int score})>[];
    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      var score = 0;
      for (final word in _words(sentence.text).toSet()) {
        score += frequency[word] ?? 0;
      }
      // Prefer early sentences slightly; books introduce the lesson first.
      if (i < 4) score += 2;
      if (sentence.text.length > 260) score -= 2;
      scored.add((index: i, sentence: sentence, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final picked = scored.take(count).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return picked.map((entry) => entry.sentence).toList(growable: false);
  }

  Iterable<String> _words(String text) => normalizeArabic(text)
      .toLowerCase()
      .split(RegExp(r'[^؀-ۿa-zA-Z0-9]+'))
      .where((word) => word.length >= 3 && !_stopwords.contains(word));

  _Term? _termInSentence(String sentence, List<_Term> terms) {
    final normalized = normalizeArabic(sentence);
    for (final term in terms) {
      if (normalizeArabic(term.term).isEmpty) continue;
      if (normalized.contains(normalizeArabic(term.term))) return term;
    }
    return null;
  }

  List<StudyCitation> _citationsFromPages(OfficialPassage passage) => [
    for (final page in passage.pages.take(6))
      if (page.text.trim().isNotEmpty)
        StudyCitation(
          page: page.pageNumber,
          quote: _ellipsis(page.text.trim(), 200),
        ),
  ];

  String _cardId(OfficialPassage passage, String suffix) =>
      'official-${passage.book.id}-${passage.section.id}-$suffix';

  static String _ellipsis(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trimRight()}…';
  }

  static const Set<String> _stopwords = {
    'من', 'في', 'على', 'إلى', 'الى', 'عن', 'أن', 'ان', 'إن', 'اذا', 'إذا',
    'التي', 'الذي', 'الذين', 'هذا', 'هذه', 'ذلك', 'تلك', 'كان', 'كانت',
    'يكون', 'تكون', 'مع', 'كل', 'بعض', 'غير', 'بين', 'حيث', 'كما', 'لكن',
    'أو', 'او', 'ثم', 'قد', 'ما', 'لا', 'لم', 'لن', 'هو', 'هي', 'هم',
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'are', 'was',
    'were', 'have', 'has', 'not', 'you', 'your', 'can', 'will', 'shall',
  };
}

class _Sentence {
  const _Sentence(this.text, this.page);

  final String text;
  final int page;
}

class _Term {
  const _Term(this.term, this.definition, this.page);

  final String term;
  final String definition;
  final int page;
}

class _Formula {
  const _Formula(this.text, this.page);

  final String text;
  final int page;

  @override
  String toString() => text;
}

class _Step {
  const _Step(this.text, this.page);

  final String text;
  final int page;
}
