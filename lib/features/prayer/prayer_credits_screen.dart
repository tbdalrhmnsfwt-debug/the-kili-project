/// The attribution required by the bundled adhan recordings.
///
/// Only recordings whose license asks for visible credit (CC BY) are listed
/// here.  CC0 and public-domain recordings need no attribution, so they stay
/// in `assets/adhan/LICENSES.md` only.  Kept in sync by hand with that file
/// and `lib/core/adhan_voices.dart`.
library;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/adhan_voices.dart';
import '../../widgets/tr_text.dart';

class PrayerCreditsScreen extends StatelessWidget {
  const PrayerCreditsScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('مش قادرين نفتح الرابط على الجهاز ده.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attributed = AdhanVoiceCatalog.instance.voices
        .where((voice) => voice.requiresAttribution)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const TrText('حول والتراخيص')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              _IntroCard(),
              const SizedBox(height: 18),
              const _SectionLabel(title: 'بيانات الإسناد المطلوبة'),
              const SizedBox(height: 8),
              if (attributed.isEmpty)
                _NoAttributionCard()
              else
                for (final voice in attributed) ...[
                  _VoiceLicenseCard(
                    voice: voice,
                    onSource: () => _open(context, voice.sourceUrl),
                    onLicense: () => _open(context, voice.licenseUrl),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 10),
              const _SectionLabel(title: 'ملاحظات'),
              const SizedBox(height: 8),
              _NotesCard(),
              const SizedBox(height: 14),
              TrText(
                'القائمة الكاملة بكل ملفات الأذان ومصادرها وتراخيصها موجودة '
                'في assets/adhan/LICENSES.md داخل المشروع.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                  fontSize: 9.8,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.10),
            theme.cardTheme.color ?? theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.32 : 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMusicNote02,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TrText(
                  'التراخيص والإسناد',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          TrText(
            'التسجيلات اللي ترخيصها بيطلب ذكر المصدر (CC BY) بس هي اللي '
            'بتظهر هنا ببيانات الإسناد. باقي الأصوات ملكية عامة أو CC0 '
            'ومش بتحتاج إسناد ظاهر.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.8,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceLicenseCard extends StatelessWidget {
  const _VoiceLicenseCard({
    required this.voice,
    required this.onSource,
    required this.onLicense,
  });

  final AdhanVoice voice;
  final VoidCallback onSource;
  final VoidCallback onLicense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TrText(
                  voice.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (voice.isFajr)
                _SmallBadge(label: 'فجر', color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 5),
          _InfoRow(label: 'الملف', value: 'res/raw/${voice.resource}.mp3'),
          _InfoRow(
            label: 'المنشد / الرافع',
            value: voice.reciter.isEmpty ? 'غير معروف' : voice.reciter,
          ),
          const SizedBox(height: 3),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              _LinkButton(
                icon: HugeIcons.strokeRoundedLink01,
                label: 'المصدر',
                onTap: onSource,
              ),
              _LinkButton(
                icon: HugeIcons.strokeRoundedLicense,
                label: voice.license,
                onTap: onLicense,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(9),
            ),
            child: TrText(
              voice.attribution,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: TrText(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9.8,
                height: 1.45,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 13, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              TrText(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.open_in_new_rounded,
                size: 11,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TrText(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 8.5,
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Note(
            text:
                'كل الأصوات المرفقة من مصادر مفتوحة (ملكية عامة أو CC0 أو '
                'CC BY)، وبتشتغل من غير إنترنت.',
            last: false,
          ),
          _Note(
            text:
                'ملفات CC BY معدّلة (مضغوطة ومطبَّعة الصوت)، والترخيص '
                'بيسمح بده مع ذكر المصدر والمنشد.',
            last: false,
          ),
          _Note(
            text:
                'مفيش صوت اتولّد أو اتصنع صناعيًا، واترفضت تسجيلات تانية '
                'لأن ترخيصها مش واضح أو مش بيسمح بالاستخدام.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _NoAttributionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: TrText(
        'مفيش أصوات محتاجة إسناد ظاهر دلوقتي.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10.5,
          height: 1.55,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.last});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9.8,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 7),
        TrText(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}
