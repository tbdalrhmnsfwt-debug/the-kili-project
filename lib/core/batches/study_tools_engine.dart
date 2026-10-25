/// Builds a local interactive test, information bank and mind map from the
/// text of one PDF, and lets nothing through that the source cannot support.
///
/// Everything here is extractive: prompts, choices and evidence are sentences,
/// terms and definitions the file actually prints. The generators run locally,
/// deterministically per document, and every question is re-checked by
/// [EvidenceValidator] before it is offered.
library;

import 'dart:math' as math;

import '../../models/extraction.dart';
import '../../models/study_source.dart';
import '../book_sectioning.dart';
import 'evidence_validator.dart';

/// The first reason a question is not good enough to show.
enum StudyRejection {
  none,
  shortPrompt,
  truncatedStem,
  tooFewChoices,
  duplicateChoices,
  invalidCorrectIndex,
  answerNotInSource,
  answerInStem,
  evidenceMissing,
}

class StudyValidation {
  const StudyValidation.ok() : rejection = StudyRejection.none;

  const StudyValidation.rejected(this.rejection);

  final StudyRejection rejection;

  bool get isValid => rejection == StudyRejection.none;
}

/// Generates the three study tools from a [SourceDocument].
///
/// A document with no usable text yields an empty test, an empty bank and a
/// mind map that says so; it never yields invented material.
class StudyToolsEngine {
  const StudyToolsEngine({this.maxTestQuestions = 10, this.maxFacts = 60});

  final int maxTestQuestions;
  final int maxFacts;

  /// The generated test. At most [limit] questions, in a deterministic order.
  List<StudyQuestion> test(SourceDocument document, {int? limit}) {
    final target = (limit ?? maxTestQuestions).clamp(1, 50);
    final sentences = _sentences(document);
    final terms = _terms(document);
    final documentText = EvidenceValidator.normalize(
      document.pages.map((page) => page.text).join('\n'),
    );
    final random = math.Random(_seed('${document.resourceId}:test'));
    final questions = <StudyQuestion>[];
    var counter = 0;

    StudyQuestion? build({
      required StudyQuestionKind kind,
      required String prompt,
      required List<String> choices,
      required int correctIndex,
      required _Line evidence,
      required String explanation,
      String difficulty = 'medium',
    }) {
      counter += 1;
      final question = StudyQuestion(
        id: '${document.resourceId}-q$counter',
        kind: kind,
        prompt: prompt,
        choices: choices,
        correctIndex: correctIndex,
        page: evidence.page,
        evidence: evidence.text,
        explanation: explanation,
        difficulty: difficulty,
      );
      if (!_validate(question, document, documentText).isValid) return null;
      return question;
    }

    // 1. Definitions: one definition against other definitions from the file.
    final definitions = <String, _Term>{};
    for (final term in terms) {
      definitions.putIfAbsent(
        EvidenceValidator.normalize(term.definition),
        () => term,
      );
    }
    if (definitions.length >= 3) {
      for (final term in terms.take(6)) {
        if (questions.length >= target) break;
        final distractors = [
          for (final other in definitions.values)
            if (EvidenceValidator.normalize(other.definition) !=
                EvidenceValidator.normalize(term.definition))
              other.definition,
        ]..shuffle(random);
        final choices = [term.definition, ...distractors.take(3)]
          ..shuffle(random);
        if (choices.length < 3) continue;
        final question = build(
          kind: StudyQuestionKind.multipleChoice,
          prompt: 'إيه التعريف الصح لـ «${term.term}»؟',
          choices: choices,
          correctIndex: choices.indexOf(term.definition),
          evidence: term.line,
          explanation:
              'التعريف مذكور في صفحة ${term.line.page}: ${term.line.text}',
          difficulty: 'easy',
        );
        if (question != null) questions.add(question);
      }
    }

    // 2. Cloze: a real sentence with one term blanked out.
    if (terms.length >= 2) {
      for (final sentence in sentences) {
        if (questions.length >= target) break;
        if (sentence.text.length < 40 || sentence.text.length > 240) continue;
        final span = _termSpan(sentence.text, terms);
        if (span == null) continue;
        final options = [
          span.term.term,
          ...{
            for (final other in terms)
              if (other.term != span.term.term) other.term,
          }.take(3),
        ]..shuffle(random);
        if (options.length < 3) continue;
        final blanked = sentence.text.replaceRange(
          span.index,
          span.index + span.term.term.length,
          '________',
        );
        final prompt = '$blanked (املأ الفراغ)';
        final question = build(
          kind: StudyQuestionKind.cloze,
          prompt: prompt,
          choices: options,
          correctIndex: options.indexOf(span.term.term),
          evidence: sentence,
          explanation: 'النص الأصلي في صفحة ${sentence.page}: ${sentence.text}',
        );
        if (question != null) questions.add(question);
      }
    }

    // 3. True/false: a verbatim sentence, or the same sentence with a term
    // swapped for another term from the file. A swapped statement is only
    // used when the cited page provably does not contain it.
    if (terms.length >= 2) {
      const labels = ['صح', 'خطأ'];
      for (final sentence in sentences.take(8)) {
        if (questions.length >= target) break;
        if (sentence.text.length > 220) continue;
        final span = _termSpan(sentence.text, terms);
        if (span == null) continue;
        final swap = random.nextBool();
        var statement = sentence.text;
        var correctIndex = 0;
        if (swap) {
          final other = terms.firstWhere(
            (candidate) => candidate.term != span.term.term,
          );
          statement = sentence.text.replaceRange(
            span.index,
            span.index + span.term.term.length,
            other.term,
          );
          if (statement == sentence.text) continue;
          // A "false" statement is only false if the file does not print it
          // anywhere; checking one page would let a swapped sentence that
          // repeats later stay in the test.
          if (_foundAnywhere(document, statement)) continue;
          correctIndex = 1;
        }
        final question = build(
          kind: StudyQuestionKind.trueFalse,
          prompt: 'صح أم خطأ: $statement',
          choices: labels,
          correctIndex: correctIndex,
          evidence: sentence,
          explanation: 'النص في صفحة ${sentence.page}: ${sentence.text}',
        );
        if (question != null) questions.add(question);
      }
    }

    questions.shuffle(random);
    return questions.take(target).toList(growable: false);
  }

  /// Definitions, dates, numbers and steps, each grounded on its page.
  StudyBank bank(SourceDocument document) {
    final facts = <StudyFact>[];
    final seen = <String>{};

    void add(
      StudyFactKind kind,
      String text,
      _Line line, {
      String term = '',
    }) {
      if (facts.length >= maxFacts) return;
      final key =
          '${kind.name}|${EvidenceValidator.normalize(text)}|${line.page}';
      if (!seen.add(key)) return;
      if (!EvidenceValidator.verify(
        document,
        page: line.page,
        excerpt: line.text,
      ).isFound) {
        return;
      }
      facts.add(
        StudyFact(
          id: '${document.resourceId}-f${facts.length + 1}',
          kind: kind,
          text: text,
          page: line.page,
          excerpt: line.text,
          term: term,
        ),
      );
    }

    for (final term in _terms(document)) {
      add(
        StudyFactKind.definition,
        term.definition,
        term.line,
        term: term.term,
      );
    }
    for (final sentence in _sentences(document)) {
      if (_datePattern.hasMatch(sentence.text)) {
        add(StudyFactKind.date, sentence.text, sentence);
      } else if (_numberUnitPattern.hasMatch(sentence.text)) {
        add(StudyFactKind.number, sentence.text, sentence);
      }
    }
    for (final step in _steps(document)) {
      add(StudyFactKind.step, step.text, step);
    }

    facts.sort((a, b) => a.page.compareTo(b.page));
    return StudyBank(resourceId: document.resourceId, facts: facts);
  }

  /// A heading/term hierarchy. Headings are the ones the file prints; when it
  /// prints none, concepts are grouped without inventing a lesson title.
  StudyMindMap mindMap(SourceDocument document) {
    final terms = _terms(document);
    final steps = _steps(document);
    final extracted = [
      for (final page in document.pages)
        ExtractedPage(
          pageNumber: page.pageNumber,
          text: page.text,
          fromOcr: page.fromOcr,
        ),
    ];
    final sections = buildSections(extracted, <String>[])
        .where((section) => !section.isFallback)
        .take(8)
        .toList(growable: false);

    final children = <StudyMapNode>[];
    final usedTerms = <String>{};

    if (sections.isNotEmpty) {
      for (var index = 0; index < sections.length; index++) {
        final section = sections[index];
        final sectionTerms = [
          for (final term in terms)
            if (term.line.page >= section.startPage &&
                term.line.page <= section.endPage)
              term,
        ].take(4).toList(growable: false);
        for (final term in sectionTerms) {
          usedTerms.add(term.term);
        }
        children.add(
          StudyMapNode(
            id: 'section$index',
            label: _trim(section.title, 90),
            page: section.startPage,
            note: 'صفحات ${section.startPage}–${section.endPage}',
            children: [
              for (var i = 0; i < sectionTerms.length; i++)
                StudyMapNode(
                  id: 'section${index}term$i',
                  label: _trim(sectionTerms[i].term, 80),
                  page: sectionTerms[i].line.page,
                ),
            ],
          ),
        );
      }
    }

    final remainingTerms = [
      for (final term in terms)
        if (!usedTerms.contains(term.term)) term,
    ].take(sections.isEmpty ? 8 : 5).toList(growable: false);
    if (remainingTerms.isNotEmpty) {
      children.add(
        StudyMapNode(
          id: 'terms',
          label: sections.isEmpty ? 'المفاهيم والتعريفات' : 'مفاهيم تانية',
          children: [
            for (var i = 0; i < remainingTerms.length; i++)
              StudyMapNode(
                id: 'term$i',
                label: _trim(remainingTerms[i].term, 80),
                page: remainingTerms[i].line.page,
              ),
          ],
        ),
      );
    }

    if (steps.isNotEmpty) {
      children.add(
        StudyMapNode(
          id: 'steps',
          label: 'خطوات مرتبة',
          children: [
            for (var i = 0; i < steps.take(5).length; i++)
              StudyMapNode(
                id: 'step$i',
                label: _trim(steps[i].text, 80),
                page: steps[i].page,
              ),
          ],
        ),
      );
    }

    if (children.isEmpty) {
      children.add(
        const StudyMapNode(
          id: 'empty',
          label: 'مفيش نص كفاية لبناء خريطة',
          note: 'راجع الصفحات المصدر',
        ),
      );
    }

    return StudyMindMap(
      resourceId: document.resourceId,
      title: document.title,
      root: StudyMapNode(
        id: 'root',
        label: document.title,
        note: document.hasUsableText
            ? 'من ${document.usablePageCount} صفحة فيها نص'
            : 'مفيش نص مقروء في الملف',
        children: children,
      ),
    );
  }

  /// Checks one question against the document it claims to come from.
  StudyValidation validate(StudyQuestion question, SourceDocument document) {
    final documentText = EvidenceValidator.normalize(
      document.pages.map((page) => page.text).join('\n'),
    );
    return _validate(question, document, documentText);
  }

  // -------------------------------------------------------------- internals

  StudyValidation _validate(
    StudyQuestion question,
    SourceDocument document,
    String documentText,
  ) {
    final prompt = question.prompt.trim();
    if (prompt.length < 12) {
      return const StudyValidation.rejected(StudyRejection.shortPrompt);
    }
    final words = prompt.split(RegExp(r'\s+'));
    if (words.length < 3) {
      return const StudyValidation.rejected(StudyRejection.truncatedStem);
    }
    final lastWord = _stripPunctuation(words.last);
    if (_danglingWords.contains(lastWord)) {
      return const StudyValidation.rejected(StudyRejection.truncatedStem);
    }

    final choices = question.choices;
    final minimumChoices = question.kind == StudyQuestionKind.trueFalse ? 2 : 3;
    if (choices.length < minimumChoices) {
      return const StudyValidation.rejected(StudyRejection.tooFewChoices);
    }
    final seen = <String>{};
    for (final choice in choices) {
      final normalized = EvidenceValidator.normalize(choice);
      if (normalized.isEmpty || !seen.add(normalized)) {
        return const StudyValidation.rejected(
          StudyRejection.duplicateChoices,
        );
      }
    }

    if (question.correctIndex < 0 || question.correctIndex >= choices.length) {
      return const StudyValidation.rejected(
        StudyRejection.invalidCorrectIndex,
      );
    }

    final answer = EvidenceValidator.normalize(choices[question.correctIndex]);
    if (question.kind != StudyQuestionKind.trueFalse) {
      if (answer.length < 2 || !documentText.contains(answer)) {
        return const StudyValidation.rejected(
          StudyRejection.answerNotInSource,
        );
      }
      if (answer.length >= 8 &&
          EvidenceValidator.normalize(prompt).contains(answer)) {
        return const StudyValidation.rejected(StudyRejection.answerInStem);
      }
    }

    final evidence = EvidenceValidator.verify(
      document,
      page: question.page,
      excerpt: question.evidence,
    );
    if (!evidence.isFound) {
      return const StudyValidation.rejected(StudyRejection.evidenceMissing);
    }
    return const StudyValidation.ok();
  }

  List<_Sentence> _sentences(SourceDocument document) {
    final sentences = <_Sentence>[];
    for (final page in document.pages) {
      for (final raw in page.text.split(_sentenceEnd)) {
        final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.length < 25 || text.length > 320) continue;
        if (text.split(RegExp(r'\s+')).length < 4) continue;
        if (RegExp(r'^[\d٠-٩.,،\s]+$').hasMatch(text)) continue;
        sentences.add(_Sentence(text, page.pageNumber));
      }
    }
    return sentences;
  }

  List<_Term> _terms(SourceDocument document) {
    final seen = <String>{};
    final terms = <_Term>[];
    for (final page in document.pages) {
      for (final raw in page.text.split(RegExp(r'[\n\r]+'))) {
        final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.length < 15 || line.length > 420) continue;
        // An ordinal step line also contains a colon; it belongs to the bank's
        // steps, not to the definition list.
        if (_stepPatterns.any((pattern) => pattern.hasMatch(line))) continue;
        final match = _colonDefinition.firstMatch(line) ??
            _copulaDefinition.firstMatch(line);
        if (match == null) continue;
        var term = match.group(1)!.trim();
        final definition = match.group(2)!.trim();
        term = term.replaceAll(RegExp(r'^[-•*\d.)\s]+'), '').trim();
        if (term.isEmpty || term.split(RegExp(r'\s+')).length > 6) continue;
        if (definition.split(RegExp(r'\s+')).length < 2) continue;
        final key = EvidenceValidator.normalize(term);
        if (key.isEmpty || !seen.add(key)) continue;
        terms.add(
          _Term(term, definition, _Line(line, page.pageNumber)),
        );
        if (terms.length >= 60) return terms;
      }
    }
    return terms;
  }

  List<_Line> _steps(SourceDocument document) {
    final steps = <_Line>[];
    for (final page in document.pages) {
      for (final raw in page.text.split(RegExp(r'[\n\r]+'))) {
        final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.length < 12 || line.length > 300) continue;
        if (!_stepPatterns.any((pattern) => pattern.hasMatch(line))) continue;
        steps.add(_Line(line, page.pageNumber));
        if (steps.length >= 30) return steps;
      }
    }
    return steps;
  }

  static bool _foundAnywhere(SourceDocument document, String excerpt) {
    for (final page in document.pages) {
      if (EvidenceValidator.contains(page.text, excerpt)) return true;
    }
    return false;
  }

  /// The literal, word-bounded occurrence of a known term in [sentence].
  ///
  /// Matching a term inside a longer word ("علم" inside "العلم") would blank
  /// the wrong span, so boundaries are required. A term spelled with
  /// diacritics in the page but not in the definition is skipped rather than
  /// replaced at a guessed position.
  ({_Term term, int index})? _termSpan(String sentence, List<_Term> terms) {
    for (final term in terms) {
      final index = _termIndex(sentence, term.term);
      if (index >= 0) return (term: term, index: index);
    }
    return null;
  }

  int _termIndex(String text, String term) {
    if (term.isEmpty) return -1;
    var index = text.indexOf(term);
    while (index >= 0) {
      final before = index == 0 ? null : text.codeUnitAt(index - 1);
      final afterIndex = index + term.length;
      final after =
          afterIndex >= text.length ? null : text.codeUnitAt(afterIndex);
      if (!_isArabicLetter(before) && !_isArabicLetter(after)) return index;
      index = text.indexOf(term, index + 1);
    }
    return -1;
  }

  static bool _isArabicLetter(int? rune) {
    if (rune == null) return false;
    return (rune >= 0x0621 && rune <= 0x063A) ||
        (rune >= 0x0641 && rune <= 0x064A) ||
        (rune >= 0x066E && rune <= 0x06D3);
  }

  static String _stripPunctuation(String value) =>
      EvidenceValidator.normalize(value).trim();

  static String _trim(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trimRight()}…';
  }

  static int _seed(String value) {
    var hash = 0x811C9DC5;
    for (final rune in value.runes) {
      hash ^= rune;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static final RegExp _sentenceEnd = RegExp(r'[.؟!?]+|\n+');
  static final RegExp _colonDefinition =
      RegExp(r'^(.{2,45}?)\s*[:：]\s*(.{10,})$');
  static final RegExp _copulaDefinition =
      RegExp(r'^(.{2,45}?)\s+(?:هو|هى|هي)\s+(.{10,})$');
  static final RegExp _datePattern = RegExp(
    r'(?<![0-9٠-٩۰-۹])(?:'
    r'[0-9٠-٩۰-۹]{1,2}[/\-.][0-9٠-٩۰-۹]{1,2}[/\-.][0-9٠-٩۰-۹]{2,4}'
    r'|[12١٢][0-9٠-٩۰-۹]{3}'
    r')(?![0-9٠-٩۰-۹])',
  );
  static final RegExp _numberUnitPattern = RegExp(
    r'[\d٠-٩]\s*(?:%|٪|كم|كيلو|متر|سم|ثانية|دقيقة|ساعة|درجة|جرام|كجم|لتر|مل)'
    r'|(?:%|٪)',
  );

  static final List<RegExp> _stepPatterns = [
    RegExp(
      r'^(أولًا|أولا|ثانيًا|ثانيا|ثالثًا|ثالثا|رابعًا|رابعا|خامسًا|خامسا)'
      r'[\s:：-]',
    ),
    RegExp(
      r'^(?:الخطوة|خطوة)\s*(?:[\d٠-٩]+|الأولى|الثانية|الثالثة|الرابعة|'
      r'الخامسة|الأول|الثاني|الثالث|الرابع|الخامس)',
    ),
    RegExp(r'^[\d٠-٩]+\s*[-.)]\s+'),
  ];

  /// Words that leave a stem hanging when they are the last thing shown.
  /// Compared after [EvidenceValidator.normalize], so they use folded forms.
  static const Set<String> _danglingWords = {
    'و',
    'او',
    'ثم',
    'في',
    'من',
    'الي',
    'علي',
    'عن',
    'ان',
    'التي',
    'الذي',
    'حيث',
    'بين',
    'مع',
    'كل',
    'اي',
  };
}

class _Line {
  const _Line(this.text, this.page);

  final String text;
  final int page;
}

class _Sentence extends _Line {
  const _Sentence(super.text, super.page);
}

class _Term {
  const _Term(this.term, this.definition, this.line);

  final String term;
  final String definition;
  final _Line line;
}
