/// "الإسلاميات": the single home for the prayer, adhan, qibla, azkar, tasbih,
/// hifz, prayer-log and diagnostics tools.
///
/// The hub only routes: every tool keeps its own screen and route, and the
/// old routes all keep working. A short first-open sheet explains each tile
/// in one line; the (i) action reopens it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/appearance.dart';
import '../../core/local_store.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/zaker_visuals.dart';
import '../prayer/prayer_log.dart';

/// Store key for the one-time hub introduction.
const String kIslamicIntroStoreKey = 'islam_intro_seen';

/// One tile in the hub.
class _HubTileData {
  const _HubTileData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    this.route,
  });

  final String title;
  final String description;
  final dynamic icon;
  final Color accent;

  /// Null until the screen ships; the tile then shows "قريبًا".
  final String? route;
}

class IslamicHubScreen extends ConsumerStatefulWidget {
  const IslamicHubScreen({super.key});

  @override
  ConsumerState<IslamicHubScreen> createState() => _IslamicHubScreenState();
}

class _IslamicHubScreenState extends ConsumerState<IslamicHubScreen> {
  bool _introScheduled = false;

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    if (_introScheduled || !mounted) return;
    _introScheduled = true;
    final seen = _store.getBool(kIslamicIntroStoreKey) ?? false;
    if (seen) return;
    await _showIntro();
    await _store.setBool(kIslamicIntroStoreKey, true);
  }

  Future<void> _showIntro() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (context) => const _IntroSheet(),
    );
  }

  List<_HubTileData> _tiles(
    ZakerFeatureAccents accents,
    bool isDark,
    int streak,
  ) {
    Color ink(Color light, Color dark) => isDark ? dark : light;

    return [
      _HubTileData(
        title: 'مواقيت الصلاة',
        description: 'مواقيت اليوم والصلوات القادمة',
        icon: HugeIcons.strokeRoundedClock01,
        accent: accents.prayer,
        route: ZakerRoutes.prayer,
      ),
      _HubTileData(
        title: 'الأذان',
        description: 'اختيار الصوت وإعدادات التنبيه',
        icon: HugeIcons.strokeRoundedVolumeHigh,
        accent: accents.prayer,
        route: ZakerRoutes.prayerNotifications,
      ),
      _HubTileData(
        title: 'القبلة',
        description: 'بوصلة حية واتجاه الكعبة',
        icon: HugeIcons.strokeRoundedKaaba01,
        accent: accents.qibla,
        route: ZakerRoutes.qibla,
      ),
      _HubTileData(
        title: 'أذكار الصباح والمساء',
        description: 'وِرد يومي بعدّاد محفوظ',
        icon: HugeIcons.strokeRoundedSunrise,
        accent: accents.azkar,
        route: ZakerRoutes.azkar,
      ),
      _HubTileData(
        title: 'الصلاة على النبي',
        description: 'عدّاد وتذكيرات على مدار اليوم',
        icon: HugeIcons.strokeRoundedStar,
        accent: accents.azkar,
        route: ZakerRoutes.azkarSalat,
      ),
      _HubTileData(
        title: 'السبحة',
        description: 'تسبيح بعدّاد بيحفظ وِردك',
        icon: HugeIcons.strokeRoundedSparkles,
        accent: ink(const Color(0xFF7C3AED), const Color(0xFFC4B5FD)),
        route: ZakerRoutes.azkarTasbih,
      ),
      _HubTileData(
        title: 'حفظ القرآن',
        description: 'حدّد سورة وآيات وسمّع لنفسك',
        icon: HugeIcons.strokeRoundedBookOpen02,
        accent: accents.hifz,
        route: ZakerRoutes.hifz,
      ),
      _HubTileData(
        title: 'سجل الصلوات',
        description: streak > 0
            ? 'سلسلتك ${_arabicNumber(streak)} '
                  '${streak == 1 ? 'يوم' : 'أيام'} — كمّل النهارده'
            : 'علّم كل صلاة وشوف سلسلتك',
        icon: HugeIcons.strokeRoundedTaskDone01,
        accent: accents.islamic,
        route: ZakerRoutes.prayerLog,
      ),
      _HubTileData(
        title: 'تشخيص الأذان',
        description: 'افحص صلاحيات الإشعارات والصوت',
        icon: HugeIcons.strokeRoundedWrench01,
        accent: ink(const Color(0xFFB45309), const Color(0xFFFBBF24)),
        route: ZakerRoutes.prayerDiagnostics,
      ),
      _HubTileData(
        title: 'القرآن الكريم',
        description: 'افتح المصحف والتلاوات',
        icon: HugeIcons.strokeRoundedBookOpen01,
        accent: accents.study,
        route: ZakerRoutes.quran,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appearance = ref.watch(appearanceProvider);
    final palette = ZakerTheme.paletteFor(appearance.themeStyle);
    final streak = ref.watch(prayerLogProvider).streak();
    final tiles = _tiles(palette.accents, palette.isDark, streak);
    final heroColors = palette.heroGradient;

    return Scaffold(
      appBar: AppBar(
        title: const TrText('الإسلاميات'),
        actions: [
          IconButton(
            tooltip: 'شرح الأدوات',
            onPressed: _showIntro,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.sm,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          _HubHero(colors: heroColors),
          const SizedBox(height: ZakerSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = ZakerSpacing.md;
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final tile in tiles)
                    SizedBox(
                      width: width,
                      child: _HubTile(
                        data: tile,
                        onTap: tile.route == null
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                context.push(tile.route!);
                              },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: ZakerSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              const Expanded(
                child: TrText(
                  'كل أدوات الصلاة والحفظ هنا في مكان واحد. '
                  'لو محتاج شرح تاني، اضغط علامة المعلومات فوق.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ZakerRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMosque01,
                size: 27,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: ZakerSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'صلاتك ووِردك في مكان واحد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 4),
                TrText(
                  'المواقيت، الأذان، القبلة، الأذكار، والحفظ.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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

class _HubTile extends StatelessWidget {
  const _HubTile({required this.data, required this.onTap});

  final _HubTileData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${data.title} — ${data.description}',
      child: ZakerPressScale(
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: ZakerRadius.card,
              child: Ink(
                padding: const EdgeInsets.all(ZakerSpacing.md),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: ZakerRadius.card,
                  border: Border.all(
                    color: data.accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ZakerGlassIcon(
                          icon: data.icon,
                          accent: data.accent,
                          size: 42,
                          iconSize: 22,
                        ),
                        const Spacer(),
                        if (!enabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                ZakerRadius.pill,
                              ),
                            ),
                            child: const TrText(
                              'قريبًا',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.md),
                    TrText(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      data.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _arabicNumber(int value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return value
      .toString()
      .split('')
      .map((digit) => digits[int.tryParse(digit) ?? 0])
      .join();
}

class _IntroSheet extends StatelessWidget {
  const _IntroSheet();

  static const List<(IconData, String, String)> _rows = [
    (
      Icons.schedule_rounded,
      'مواقيت الصلاة',
      'مواقيت اليوم والصلوات القادمة حسب موقعك.',
    ),
    (
      Icons.volume_up_rounded,
      'الأذان',
      'اختار صوت الأذان وشغّل التنبيه لكل صلاة.',
    ),
    (Icons.explore_rounded, 'القبلة', 'بوصلة حية بتوضّح اتجاه الكعبة.'),
    (
      Icons.wb_twilight_rounded,
      'أذكار الصباح والمساء',
      'وِرد يومي بعدّاد محفوظ على جهازك.',
    ),
    (
      Icons.favorite_rounded,
      'الصلاة على النبي',
      'عدّاد وتذكيرات على مدار اليوم.',
    ),
    (Icons.auto_awesome_rounded, 'السبحة', 'تسبيح بعدّاد بيحفظ وِردك.'),
    (Icons.menu_book_rounded, 'حفظ القرآن', 'حدّد سورة وآيات وسمّع لنفسك.'),
    (
      Icons.task_alt_rounded,
      'سجل الصلوات',
      'علّم كل صلاة وشوف سلسلتك اليومية.',
    ),
    (
      Icons.build_circle_outlined,
      'تشخيص الأذان',
      'افحص صلاحيات الإشعارات والصوت.',
    ),
    (Icons.auto_stories_rounded, 'القرآن الكريم', 'يفتح المصحف والتلاوات.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            0,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          children: [
            const TrText(
              'أهلاً في الإسلاميات',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            TrText(
              'دي كل أدوات الصلاة والذكر والحفظ في مكان واحد. '
              'كل أداة ليها سطر بيشرحها.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.lg),
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(ZakerRadius.sm),
                      ),
                      child: Icon(
                        row.$1,
                        size: 17,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: ZakerSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            row.$2,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TrText(
                            row.$3,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: ZakerSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const TrText('تمام، فهمت'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
