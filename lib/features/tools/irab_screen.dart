/// دليل الإعراب — a compact Arabic grammar reference and quick quiz.
///
/// The screen is deliberately an offline study aid, not a parser: it lists
/// the positions a word can take (مرفوعات، منصوبات، مجرورات، توابع), with a
/// worked example and the reason behind each إعراب. A five-question quiz at
/// the end lets the student check that the distinction stuck.
library;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';

/// One grammar position with a worked example.
class _Rule {
  const _Rule({
    required this.term,
    required this.category,
    required this.definition,
    required this.example,
    required this.irab,
  });

  final String term;
  final String category;
  final String definition;
  final String example;
  final String irab;
}

const List<String> _categories = [
  'الكل',
  'المرفوعات',
  'المنصوبات',
  'المجرورات',
  'التوابع',
];

const List<_Rule> _rules = [
  _Rule(
    term: 'الفاعل',
    category: 'المرفوعات',
    definition: 'من قام بالفعل، أو اتّصف به.',
    example: 'كتبَ الطالبُ الدرسَ.',
    irab: 'الطالبُ: فاعل مرفوع وعلامة رفعه الضمة الظاهرة.',
  ),
  _Rule(
    term: 'نائب الفاعل',
    category: 'المرفوعات',
    definition: 'اسم مرفوع يحلّ محل الفاعل عندما يُبنى الفعل للمجهول.',
    example: 'كُتِبَ الدرسُ.',
    irab: 'الدرسُ: نائب فاعل مرفوع وعلامة رفعه الضمة.',
  ),
  _Rule(
    term: 'المبتدأ',
    category: 'المرفوعات',
    definition: 'الاسم الذي تبدأ به الجملة الاسمية، ويُخبر عنه.',
    example: 'العلمُ نورٌ.',
    irab: 'العلمُ: مبتدأ مرفوع وعلامة رفعه الضمة.',
  ),
  _Rule(
    term: 'الخبر',
    category: 'المرفوعات',
    definition: 'ما يتمّ به معنى المبتدأ.',
    example: 'العلمُ نورٌ.',
    irab: 'نورٌ: خبر مرفوع وعلامة رفعه الضمة.',
  ),
  _Rule(
    term: 'اسم كان',
    category: 'المرفوعات',
    definition: 'كان وأخواتها ترفع الاسم وتنصب الخبر.',
    example: 'كانَ الجوُّ جميلًا.',
    irab: 'الجوُّ: اسم كان مرفوع وعلامة رفعه الضمة.',
  ),
  _Rule(
    term: 'خبر إنّ',
    category: 'المرفوعات',
    definition: 'إنّ وأخواتها تنصب الاسم وترفع الخبر.',
    example: 'إنّ العلمَ نافعٌ.',
    irab: 'نافعٌ: خبر إنّ مرفوع وعلامة رفعه الضمة.',
  ),
  _Rule(
    term: 'المفعول به',
    category: 'المنصوبات',
    definition: 'من وقع عليه فعل الفاعل.',
    example: 'قرأَ الطالبُ الكتابَ.',
    irab: 'الكتابَ: مفعول به منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'المفعول المطلق',
    category: 'المنصوبات',
    definition: 'مصدر منصوب يؤكّد الفعل أو يبيّن نوعه أو عدده.',
    example: 'فرحَ الطفلُ فرحًا.',
    irab: 'فرحًا: مفعول مطلق منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'المفعول لأجله',
    category: 'المنصوبات',
    definition: 'مصدر منصوب يبيّن سبب وقوع الفعل.',
    example: 'ذاكرتُ خوفًا من الرسوب.',
    irab: 'خوفًا: مفعول لأجله منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'المفعول فيه (الظرف)',
    category: 'المنصوبات',
    definition: 'اسم زمان أو مكان منصوب يبيّن وقت الفعل أو مكانه.',
    example: 'سافرتُ ليلًا.',
    irab: 'ليلًا: مفعول فيه ظرف زمان منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'الحال',
    category: 'المنصوبات',
    definition: 'هيئة الفاعل أو المفعول عند وقوع الفعل.',
    example: 'عادَ الطالبُ مسرورًا.',
    irab: 'مسرورًا: حال منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'التمييز',
    category: 'المنصوبات',
    definition: 'اسم منصوب يزيل إبهامًا في ما قبله.',
    example: 'اشتريتُ رطلًا عسلًا.',
    irab: 'عسلًا: تمييز منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'اسم إنّ',
    category: 'المنصوبات',
    definition: 'إنّ وأخواتها تنصب الاسم وترفع الخبر.',
    example: 'إنّ العلمَ نافعٌ.',
    irab: 'العلمَ: اسم إنّ منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'خبر كان',
    category: 'المنصوبات',
    definition: 'كان وأخواتها ترفع الاسم وتنصب الخبر.',
    example: 'كانَ الجوُّ جميلًا.',
    irab: 'جميلًا: خبر كان منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'المنادى',
    category: 'المنصوبات',
    definition: 'المطلوب نداؤه، ويكون منصوبًا إذا كان مضافًا.',
    example: 'يا طالبَ العلمِ، اجتهد.',
    irab: 'طالبَ: منادى منصوب وعلامة نصبه الفتحة، وهو مضاف.',
  ),
  _Rule(
    term: 'الاسم المجرور بحرف الجر',
    category: 'المجرورات',
    definition: 'كل اسم يقع بعد حرف من حروف الجر.',
    example: 'ذهبتُ إلى المدرسةِ.',
    irab: 'المدرسةِ: اسم مجرور بـ«إلى» وعلامة جره الكسرة.',
  ),
  _Rule(
    term: 'المضاف إليه',
    category: 'المجرورات',
    definition: 'اسم يقع بعد مضاف، ويُجرّ دائمًا.',
    example: 'بابُ البيتِ مفتوحٌ.',
    irab: 'البيتِ: مضاف إليه مجرور وعلامة جره الكسرة.',
  ),
  _Rule(
    term: 'النعت',
    category: 'التوابع',
    definition: 'يتبع المنعوت في إعرابه وعدده ونوعه.',
    example: 'رأيتُ طالبًا مجتهدًا.',
    irab: 'مجتهدًا: نعت منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'العطف',
    category: 'التوابع',
    definition: 'يتبع المعطوف عليه في إعرابه.',
    example: 'حضرَ محمدٌ وعليٌّ.',
    irab: 'عليٌّ: معطوف مرفوع وعلامة رفعه الضمة.',
  ),
  _Rule(
    term: 'البدل',
    category: 'التوابع',
    definition: 'يتبع المبدل منه في إعرابه.',
    example: 'قابلتُ أخاك خالدًا.',
    irab: 'خالدًا: بدل منصوب وعلامة نصبه الفتحة.',
  ),
  _Rule(
    term: 'التوكيد',
    category: 'التوابع',
    definition: 'يتبع المؤكَّد في إعرابه، لفظيًّا أو معنويًّا.',
    example: 'حضرَ الطلابُ كلُّهم.',
    irab: 'كلُّهم: توكيد معنوي مرفوع وعلامة رفعه الضمة.',
  ),
];

const Map<String, Color> _categoryColors = {
  'المرفوعات': Color(0xFF2563EB),
  'المنصوبات': Color(0xFFD97706),
  'المجرورات': Color(0xFF7C3AED),
  'التوابع': Color(0xFF059669),
};

/// A quick multiple-choice question.
class _QuizQuestion {
  const _QuizQuestion({
    required this.sentence,
    required this.word,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  final String sentence;
  final String word;
  final List<String> options;
  final int correct;
  final String explanation;
}

const List<_QuizQuestion> _questions = [
  _QuizQuestion(
    sentence: 'كتبَ الطالبُ الدرسَ.',
    word: 'الطالبُ',
    options: ['فاعل مرفوع', 'مفعول به منصوب', 'مبتدأ مرفوع'],
    correct: 0,
    explanation: 'الطالبُ هو من قام بالكتابة، فهو فاعل مرفوع بالضمة.',
  ),
  _QuizQuestion(
    sentence: 'إنّ العلمَ نافعٌ.',
    word: 'العلمَ',
    options: ['خبر إنّ مرفوع', 'اسم إنّ منصوب', 'مبتدأ مرفوع'],
    correct: 1,
    explanation: 'إنّ تنصب الاسم وترفع الخبر، فـ«العلمَ» اسم إنّ منصوب.',
  ),
  _QuizQuestion(
    sentence: 'ذهبتُ إلى المدرسةِ.',
    word: 'المدرسةِ',
    options: ['مفعول به منصوب', 'مضاف إليه مجرور', 'اسم مجرور بـ«إلى»'],
    correct: 2,
    explanation: '«إلى» حرف جر، والاسم بعده مجرور وعلامة جره الكسرة.',
  ),
  _QuizQuestion(
    sentence: 'عادَ الطالبُ مسرورًا.',
    word: 'مسرورًا',
    options: ['حال منصوب', 'خبر كان منصوب', 'تمييز منصوب'],
    correct: 0,
    explanation: '«مسرورًا» بيّن هيئة الطالب عند عودته، فهو حال منصوب.',
  ),
  _QuizQuestion(
    sentence: 'كانَ الجوُّ جميلًا.',
    word: 'جميلًا',
    options: ['اسم كان مرفوع', 'خبر كان منصوب', 'نعت منصوب'],
    correct: 1,
    explanation: 'كان ترفع الاسم وتنصب الخبر، فـ«جميلًا» خبر كان منصوب.',
  ),
];

/// The grammar reference screen.
class IrabScreen extends StatefulWidget {
  const IrabScreen({super.key});

  @override
  State<IrabScreen> createState() => _IrabScreenState();
}

class _IrabScreenState extends State<IrabScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'الكل';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Rule> get _visible {
    final query = _query.trim();
    return _rules.where((rule) {
      final inCategory = _category == 'الكل' || rule.category == _category;
      if (!inCategory) return false;
      if (query.isEmpty) return true;
      return rule.term.contains(query) ||
          rule.definition.contains(query) ||
          rule.example.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final rules = _visible;

    return Scaffold(
      appBar: AppBar(title: const TrText('دليل الإعراب')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _Hero(),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث عن فاعل، مفعول، حال…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _categories[index];
                    final selected = item == _category;
                    return ChoiceChip(
                      label: TrText(item),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: TrText(
                    'مفيش نتيجة للبحث ده — جرّب كلمة تانية.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final rule in rules) ...[
                  _RuleCard(rule: rule),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 18),
              const _QuizSection(questions: _questions),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ZakerColors.primary, ZakerColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ZakerColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPen01,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'اتعلم الإعراب خطوة بخطوة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                TrText(
                  'المرفوعات والمنصوبات والمجرورات والتوابع — بأمثلة معربة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCCFBF1),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- rule card

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});

  final _Rule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _categoryColors[rule.category] ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: HugeIcon(icon: HugeIcons.strokeRoundedPen01, size: 20, color: accent),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: TrText(
                  rule.term,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TrText(
                  rule.category,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TrText(
              rule.definition,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText(
                    rule.example,
                    style: TextStyle(
                      fontFamily: ZakerTheme.fontQuran,
                      fontSize: 20,
                      height: 1.7,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_left_rounded,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TrText(
                          rule.irab,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------- quiz

class _QuizSection extends StatefulWidget {
  const _QuizSection({required this.questions});

  final List<_QuizQuestion> questions;

  @override
  State<_QuizSection> createState() => _QuizSectionState();
}

class _QuizSectionState extends State<_QuizSection> {
  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;

  void _choose(int option) {
    if (_selected != null) return;
    setState(() {
      _selected = option;
      if (option == widget.questions[_index].correct) _score++;
    });
  }

  void _next() {
    setState(() {
      if (_index == widget.questions.length - 1) {
        _finished = true;
        return;
      }
      _index++;
      _selected = null;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _selected = null;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_finished) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ZakerColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 28,
                  color: ZakerColors.success,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TrText(
              'خلصت التمرين!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            TrText(
              'نتيجتك $_score من ${widget.questions.length}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('جرّب تاني'),
            ),
          ],
        ),
      );
    }

    final question = widget.questions[_index];
    final answered = _selected != null;
    final isCorrect = _selected == question.correct;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedIdea01,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TrText(
                  'اختبر نفسك',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TrText(
                '${_index + 1} / ${widget.questions.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TrText(
            question.sentence,
            style: TextStyle(
              fontFamily: ZakerTheme.fontQuran,
              fontSize: 21,
              height: 1.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TrText(
            'إيه إعراب «${question.word}»؟',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < question.options.length; i++) ...[
            _OptionButton(
              label: question.options[i],
              index: i,
              answered: answered,
              selected: _selected == i,
              correct: question.correct,
              onTap: () => _choose(i),
            ),
            if (i != question.options.length - 1) const SizedBox(height: 8),
          ],
          if (answered) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isCorrect ? ZakerColors.success : ZakerColors.danger)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TrText(
                '${isCorrect ? 'صح! ' : 'مش دقيق. '}${question.explanation}',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                child: TrText(
                  _index == widget.questions.length - 1
                      ? 'شوف النتيجة'
                      : 'السؤال اللي بعده',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.index,
    required this.answered,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool answered;
  final bool selected;
  final int correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = index == correct;
    final wrongPick = answered && selected && !isCorrect;

    final Color border;
    final Color background;
    if (!answered) {
      border = theme.dividerTheme.color ?? Colors.black12;
      background = Colors.transparent;
    } else if (isCorrect) {
      border = ZakerColors.success;
      background = ZakerColors.success.withValues(alpha: 0.08);
    } else if (wrongPick) {
      border = ZakerColors.danger;
      background = ZakerColors.danger.withValues(alpha: 0.08);
    } else {
      border = theme.dividerTheme.color ?? Colors.black12;
      background = Colors.transparent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TrText(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (answered && isCorrect)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: ZakerColors.success,
                )
              else if (wrongPick)
                const Icon(
                  Icons.cancel_rounded,
                  size: 20,
                  color: ZakerColors.danger,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
