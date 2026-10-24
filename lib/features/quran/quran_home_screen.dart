/// The Quran tab: adhkar, recitation, and the mutashabihat tool.
///
/// The app reaches the recitation servers recovered from the APK:
///   * `https://cdn.islamic.network/quran/audio/r...`  (per-ayah audio)
///   * `https://audio-cdn.tarteel.ai/quran/surah/...`
///   * `https://api.alquran.cloud/v1/surah/...`
///   * `https://download.quranicaudio.com/quran/...`
///   * `https://server{6,11,12,16}.mp3quran.net/`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../hifz/hifz_home_screen.dart';
import 'adhkar_screen.dart';
import 'mutashabihat_screen.dart';
import 'quran_reader_screen.dart';
import 'tajweed_screen.dart';
import 'tasbih_screen.dart';
import '../home/shell_screen.dart';
import '../../widgets/tr_text.dart';

/// The Quran tab.
class QuranHomeScreen extends ConsumerWidget {
  const QuranHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuLeading(context),
        title: const TrText('القرآن الكريم'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _Hero(
            title: ZakerStrings.s_c2dba, // اسمع التلاوة
            subtitle: ZakerStrings.s_336bc, // المصحف كامل — واستمع بصوت الشيخ
            icon: Icons.headphones_rounded,
            color: theme.colorScheme.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const QuranReaderScreen(),
              ),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _Hero(
            title: 'احفظ وسمّع',
            subtitle: 'حدد سورة وآيات، خبّي الكلمات وسمّع لنفسك',
            icon: Icons.psychology_alt_rounded,
            color: ZakerColors.success,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HifzHomeScreen()),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _Hero(
            title: ZakerStrings.s_265c6, // المسبحة
            subtitle: 'سبح بإيدك — وعداد بيحفظ وِردك',
            icon: Icons.fingerprint_rounded,
            color: theme.colorScheme.secondary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TasbihScreen()),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _Hero(
            title: ZakerStrings.s_f9f8b, // الأذكار
            subtitle:
                ZakerStrings.s_4d249, // أذكار الصباح والمساء — بعداد يمشي معاك
            icon: Icons.spa_rounded,
            color: ZakerColors.accent,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdhkarScreen()),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _Hero(
            title: ZakerStrings.s_be531, // المتشابهات
            subtitle: ZakerStrings.s_b290f, // كل آية في السورة ليها نظير
            icon: Icons.compare_arrows_rounded,
            color: ZakerColors.primaryLight,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MutashabihatScreen(),
              ),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _Hero(
            title: ZakerStrings.s_5e8f1, // أحكام التجويد والترتيل المتقن
            subtitle: ZakerStrings.s_b1145, // ترتيل هادئ
            icon: Icons.record_voice_over_rounded,
            color: theme.colorScheme.secondary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TajweedScreen()),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _Hero(
            title: ZakerStrings.s_7b273, // اقرا صفحة من المصحف
            subtitle: 'المصحف كامل — اقرا أي سورة',
            icon: Icons.auto_stories_rounded,
            color: theme.colorScheme.tertiary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const QuranReaderScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large tappable card.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(ZakerRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: ZakerSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
