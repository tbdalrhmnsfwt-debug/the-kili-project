/// The small About / Licenses entry for the azkar feature.
///
/// Attribution lives here and only here.  The azkar and salat screens never
/// show licence text: they only say whether a recording is available.
library;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'azkar_widgets.dart';

class AzkarLicensesScreen extends StatelessWidget {
  const AzkarLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const TrText('حول والتراخيص')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          const AzkarHero(
            eyebrow: 'مصادر واضحة',
            title: 'أصوات وبيانات',
            subtitle: 'كل ملف مرفق مع التطبيق مصدره موضّح هنا. مفيش تسجيلات من تطبيقات تانية.',
            icon: HugeIcons.strokeRoundedLicense,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
          ),
          const SizedBox(height: 18),
          AzkarSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ZakerColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.volume_off_rounded,
                          color: ZakerColors.accent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: TrText(
                        'مفيش تسجيل خارجي للصيغ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'بحثنا في Wikimedia Commons وInternet Archive وFreesound عن تسجيل '
                  'للصيغ الثلاث بترخيص Public Domain أو CC0 أو CC-BY. '
                  'ملقيناش تسجيل مطابق بالترخيص المطلوب، فالتطبيق مش بيضم أي تسجيل خارجي '
                  'للصيغ، والصيغ بتشتغل كنص إشعار أو بنغمة أو صامتة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 10,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 12),
                for (final phrase in const <String>[
                  'صلِّ على محمد',
                  'صلِّ على سيدنا محمد',
                  'اللهم صلِّ وسلِّم وزد وبارك على سيدنا محمد',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: ZakerColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phrase,
                            style: TextStyle(
                              fontFamily: ZakerTheme.fontQuran,
                              fontSize: 14,
                              height: 1.7,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ZakerColors.accent.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'نص فقط',
                            style: TextStyle(
                              color: cardAccentOnTintOf(
                                ZakerColors.accent,
                                theme,
                                alpha: 0.11,
                              ),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AzkarSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMusicNote02,
                          size: 19,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: TrText(
                        'نغمة التنبيه',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      'app-generated',
                      style: TextStyle(
                        color: muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'chime.mp3 مدتها ٢٫٦ ثانية، mono، بجودة 48 kbps وحجم حوالي 16 KB. '
                  'اتولّدت خصيصًا للتطبيق من نغمات sine صناعية، ومفيش فيها أي تسجيل '
                  'لطرف تالت، فمش محتاجة نسبة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 10,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'نفس الملف موجود كـ raw resource عشان قناة إشعارات أندرويد تقدر تستخدمه.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 9,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AzkarSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AzkarSectionHeader(
                  title: 'ملفات تضيفها بنفسك',
                  subtitle: 'التطبيق بيلقطها تلقائيًا',
                  icon: HugeIcons.strokeRoundedFolder01,
                ),
                const SizedBox(height: 10),
                Text(
                  'لو عندك تسجيل مرخّص للصيغ، حطه في assets/salat بالاسم:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 10,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 8),
                for (final name in const <String>[
                  'asal_ala_muhammad_*.mp3',
                  'asal_ala_sayyidina_muhammad_*.mp3',
                  'allahumma_salli_*.mp3',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        name,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 9,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'التسجيل بيتشغّل من شاشة الذكر. الإشعار نفسه بيستخدم التسجيل فقط لو '
                  'اتضاف كـ raw resource في أندرويد؛ غير كده بيظهر نص وصامت. '
                  'مسؤولية حقوق أي ملف بتضيفه عليك.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 9,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AzkarSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedBookOpen01,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: const TrText(
                    'نصوص الأذكار',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: Text(
                    'assets/data/azkar.json — نسخة حرفية من بيانات الأذكار المرفقة أصلًا '
                    'مع التطبيق. مفيش نص أذكار مكتوب من الذاكرة.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 9,
                      height: 1.5,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                ListTile(
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'زاكِر',
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedLicense,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: const TrText(
                    'تراخيص المكتبات مفتوحة المصدر',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Flutter والحزم المستخدمة.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'آخر مراجعة للمصادر: ٢٤ أكتوبر ٢٠٢٦.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
