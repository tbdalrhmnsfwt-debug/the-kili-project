/// A concise tajweed reference: the rules a student needs while reciting.
///
/// Each card carries the rule, a plain explanation, and a Quranic example in
/// the Amiri face. The content is a study aid, not a substitute for a teacher.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// One tajweed rule.
class _Rule {
  const _Rule({
    required this.title,
    required this.summary,
    required this.explanation,
    required this.example,
    this.note,
  });

  final String title;
  final String summary;
  final String explanation;
  final String example;
  final String? note;
}

/// A group of related rules.
class _Chapter {
  const _Chapter(this.title, this.rules);

  final String title;
  final List<_Rule> rules;
}

const List<_Chapter> _chapters = [
  _Chapter('أحكام النون الساكنة والتنوين', [
    _Rule(
      title: 'الإظهار',
      summary: 'نُنطق النون واضحة من غير غنة',
      explanation:
          'إذا جاءت النون الساكنة أو التنوين قبل حرف من حروف الحلق '
          '(ء، هـ، ع، ح، غ، خ) نُظهر النون وننطقها واضحة.',
      example: 'مَنْ آمَنَ — عَلِيمٌ حَكِيمٌ',
      note: 'حروف الحلق ستة: ء هـ ع ح غ خ.',
    ),
    _Rule(
      title: 'الإدغام',
      summary: 'ندخل النون في الحرف اللي بعدها',
      explanation:
          'إذا جاء بعد النون الساكنة أو التنوين حرف من (ي، ن، م، و) '
          'ندغم النون فيه بغنة، ومن (ل، ر) ندغمها من غير غنة.',
      example: 'مَن يَعْمَلْ — مِن رَّبِّهِمْ',
      note: 'بغنة: ينمو. بغير غنة: ل، ر.',
    ),
    _Rule(
      title: 'الإقلاب',
      summary: 'نحوّل النون ميمًا مخفاة',
      explanation:
          'إذا جاءت النون الساكنة أو التنوين قبل الباء، تُقلب النون ميمًا '
          'وتُخفى مع غنة بمقدار حركتين.',
      example: 'مِن بَعْدِ — سَمِيعٌ بَصِيرٌ',
    ),
    _Rule(
      title: 'الإخفاء',
      summary: 'نخفي النون مع غنة',
      explanation:
          'إذا جاء بعد النون الساكنة أو التنوين أحد الحروف الخمسة عشر '
          'الباقية، نخفي النون ونعطيها غنة بمقدار حركتين.',
      example: 'مِن قَبْلِ — أَنْعَمْتَ',
      note: 'الحروف: ص ذ ث ك ج ش ق س د ط ز ف ت ض ظ.',
    ),
  ]),
  _Chapter('المدود', [
    _Rule(
      title: 'المد الطبيعي',
      summary: 'حركتان فقط',
      explanation:
          'إذا جاء حرف المد (ا، و، ي) ولم يأتِ بعده همز أو سكون، '
          'نمدّه بمقدار حركتين.',
      example: 'قَالَ — يَقُولُ — فِي',
    ),
    _Rule(
      title: 'المد المتصل',
      summary: 'أربع أو خمس حركات',
      explanation:
          'إذا جاء حرف المد وبعده همز في نفس الكلمة، وجب مدّه '
          'أربع أو خمس حركات.',
      example: 'جَاءَ — السَّمَاءِ',
    ),
    _Rule(
      title: 'المد المنفصل',
      summary: 'أربع أو خمس حركات',
      explanation:
          'إذا جاء حرف المد في آخر الكلمة وجاء الهمز في أول الكلمة '
          'التي بعدها، جاز مدّه أربع أو خمس حركات.',
      example: 'بِمَا أُنزِلَ — يَا أَيُّهَا',
    ),
    _Rule(
      title: 'المد اللازم',
      summary: 'ست حركات',
      explanation:
          'إذا جاء بعد حرف المد حرف ساكن أصلي أو حرف مشدد في نفس '
          'الكلمة، وجب مدّه ست حركات.',
      example: 'الضَّالِّينَ — الْحَاقَّةُ',
    ),
    _Rule(
      title: 'المد العارض للسكون',
      summary: 'حركتان إلى ست',
      explanation:
          'إذا وقفنا على كلمة آخرها حرف مد وبعده سكون عارض بسبب الوقف، '
          'نمدّه حركتين أو أربعًا أو ستًا.',
      example: 'الرَّحِيمِ — نَسْتَعِينُ',
    ),
  ]),
  _Chapter('القلقلة والغنة', [
    _Rule(
      title: 'القلقلة',
      summary: 'اهتزاز الحرف عند سكونه',
      explanation:
          'إذا سكن حرف من حروف (ق، ط، ب، ج، د) ننطقه بقلقلة، '
          'وتكون أقوى عند الوقف.',
      example: 'قُلْ — اقْرَأْ — أَحَدْ',
      note: 'اجمعها في: قطب جد.',
    ),
    _Rule(
      title: 'الغنة',
      summary: 'صوت يخرج من الخيشوم',
      explanation:
          'النون والميم المشددتان تُغنان بمقدار حركتين، وكذلك النون '
          'والميم الساكنتان في حال الإخفاء أو الإدغام بغنة.',
      example: 'إِنَّ — ثُمَّ — عَمَّ',
    ),
  ]),
  _Chapter('التفخيم والترقيق', [
    _Rule(
      title: 'التفخيم',
      summary: 'نُسمّن صوت الحرف',
      explanation:
          'حروف الاستعلاء (خ، ص، ض، غ، ط، ق، ظ) تُفخّم دائمًا، '
          'وكذلك الألف بعدها. والراء تُفخّم إذا كانت مفتوحة أو مضمومة.',
      example: 'خَلَقَ — قَالَ — رَبِّ',
    ),
    _Rule(
      title: 'الترقيق',
      summary: 'نُنطق الحرف نحيفًا',
      explanation:
          'حروف الاستفال تُرقّق، والألف بعدها، واللام في لفظ الجلالة '
          'تُرقّق إذا سبقها كسر.',
      example: 'كَتَبَ — بِسْمِ اللَّهِ',
    ),
  ]),
];

/// The tajweed reference screen.
class TajweedScreen extends StatefulWidget {
  const TajweedScreen({super.key});

  @override
  State<TajweedScreen> createState() => _TajweedScreenState();
}

class _TajweedScreenState extends State<TajweedScreen> {
  String _query = '';

  List<_Chapter> get _visible {
    final query = _query.trim();
    if (query.isEmpty) return _chapters;
    return [
      for (final chapter in _chapters)
        if (chapter.rules.any(
          (r) =>
              r.title.contains(query) ||
              r.summary.contains(query) ||
              r.explanation.contains(query),
        ))
          _Chapter(
            chapter.title,
            chapter.rules
                .where(
                  (r) =>
                      r.title.contains(query) ||
                      r.summary.contains(query) ||
                      r.explanation.contains(query),
                )
                .toList(growable: false),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _visible;

    return Scaffold(
      appBar: AppBar(title: const TrText('أحكام التجويد')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: ZakerRadius.card,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  ZakerColors.navy,
                  ZakerColors.primaryDark,
                ],
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        'رتّل واتقن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      TrText(
                        'قواعد التجويد الأساسية بأمثلة من القرآن — '
                        'اقرا القاعدة وجرّبها بصوتك.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'دوّر على قاعدة…',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          if (chapters.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'مفيش قاعدة بالاسم ده',
              message: 'جرّب تكتب اسم القاعدة أو جزء من شرحها.',
            )
          else
            for (final chapter in chapters) ...[
              SectionHeader(
                title: chapter.title,
                icon: Icons.auto_stories_rounded,
              ),
              for (final rule in chapter.rules)
                _RuleCard(rule: rule, initiallyExpanded: _query.isNotEmpty),
            ],
        ],
      ),
    );
  }
}

/// One expandable rule card.
class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.initiallyExpanded});

  final _Rule rule;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.md,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            ZakerSpacing.md,
            0,
            ZakerSpacing.md,
            ZakerSpacing.md,
          ),
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
            ),
            child: Icon(
              Icons.bookmark_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          title: TrText(
            rule.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: TrText(
            rule.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TrText(
                rule.explanation,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.8),
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZakerSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(ZakerRadius.sm),
              ),
              child: TrText(
                rule.example,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ZakerTheme.fontQuran,
                  fontSize: 21,
                  height: 1.9,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (rule.note != null) ...[
              const SizedBox(height: ZakerSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TrText(
                  rule.note!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
