/// "تشخيص الأذان": one checklist that explains why an adhan may not arrive
/// and offers the system fix for each item, plus two live tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/adhan_voices.dart';
import '../../core/appearance.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_formats.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../prayer/adhan_providers.dart';
import '../prayer/prayer_models.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool? _notifications;
  bool? _exactAlarms;
  bool? _fullScreen;
  bool? _battery;
  bool? _overlay;
  bool _channelsCreated = false;
  ({int id, String title, DateTime? when})? _nextPrayer;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final service = NotificationService.instance;
    bool? overlay;
    bool? fullScreen;
    bool? battery;
    await service.init();
    await service.ensureAdhanChannels();
    final results = await Future.wait<Object?>([
      service.areNotificationsEnabled(),
      service.canScheduleExactNotifications(),
      AdhanPlatform.canUseFullScreenIntent(),
      AdhanPlatform.isIgnoringBatteryOptimizations(),
      AdhanPlatform.canDrawOverlays(),
      service.nextScheduledPrayer(),
    ]);
    overlay = results[4] as bool?;
    fullScreen = results[2] as bool?;
    battery = results[3] as bool?;
    if (!mounted) return;
    setState(() {
      _notifications = results[0] as bool;
      _exactAlarms = results[1] as bool;
      _fullScreen = fullScreen ?? true;
      _battery = battery ?? true;
      _overlay = overlay ?? false;
      _channelsCreated = true;
      _nextPrayer = results[5] as ({int id, String title, DateTime? when})?;
      _loading = false;
    });
  }

  Future<bool> _explainNotifications() async {
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('إذن الإشعارات'),
        content: const TrText(
          'عشان الأذان وتذكير الصلاة يوصلك في ميعادهم، التطبيق محتاج إذن '
          'الإشعارات. من غير الإذن مش هنقدر نعرض لك التنبيه.',
          style: TextStyle(fontSize: 13, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TrText('مش دلوقتي'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const TrText('اسمح'),
          ),
        ],
      ),
    );
    return allow ?? false;
  }

  Future<void> _fixNotifications() async {
    if (!await _explainNotifications()) return;
    await NotificationService.instance.requestPermission();
    if (!mounted) return;
    final allowed = await NotificationService.instance
        .areNotificationsEnabled();
    if (!allowed && mounted) {
      await AdhanPlatform.openAppSettings();
      return;
    }
    await _load();
  }

  Future<void> _fixExactAlarms() async {
    await NotificationService.instance.requestExactAlarmsPermission();
    await _load();
  }

  Future<void> _fixFullScreen() async {
    await AdhanPlatform.requestFullScreenIntentPermission();
    await _load();
  }

  Future<void> _fixBattery() async {
    await AdhanPlatform.requestIgnoreBatteryOptimizations();
    await _load();
  }

  Future<void> _fixOverlay() async {
    await AdhanPlatform.requestOverlayPermission();
    await _load();
  }

  Future<void> _testAdhan() async {
    if (_testing) return;
    setState(() => _testing = true);
    final settings = ref.read(adhanSettingsProvider);
    final voice = adhanVoiceById(settings.voiceIdFor(PrayerName.dhuhr));
    final ok = await NotificationService.instance.showTestAdhan(voice);
    if (!mounted) return;
    setState(() => _testing = false);
    _toast(
      ok
          ? 'اتبعت إشعار تجربة الأذان — لو مش شايفه، راجع الإشعارات فوق.'
          : 'مش قدرنا نبعت الإشعار. راجع إذن الإشعارات.',
    );
  }

  Future<void> _testDelayed() async {
    if (_testing) return;
    setState(() => _testing = true);
    final outcome = await NotificationService.instance.scheduleTestNotification(
      delay: const Duration(seconds: 10),
    );
    if (!mounted) return;
    setState(() => _testing = false);
    _toast(
      outcome == AdhanScheduleOutcome.failed
          ? 'مش قدرنا نجدول الاختبار.'
          : 'الإشعار هيوصل بعد 10 ثواني. اقفل التطبيق واستنى.',
    );
    await _load();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ZakerTheme.paletteFor(
      ref.watch(appearanceProvider).themeStyle,
    );
    return Scaffold(
      appBar: AppBar(
        title: const TrText('تشخيص الأذان'),
        actions: [
          IconButton(
            tooltip: 'إعادة الفحص',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                ZakerSpacing.sm,
                ZakerSpacing.lg,
                ZakerSpacing.xxl,
              ),
              children: [
                _Header(colors: palette.heroGradient),
                const SizedBox(height: ZakerSpacing.lg),
                const SectionHeader(
                  title: 'قائمة الفحص',
                  icon: Icons.checklist_rounded,
                ),
                _CheckRow(
                  title: 'إذن الإشعارات',
                  detail: _notifications == true
                      ? 'الإشعارات مسموحة.'
                      : 'مقفولة — الأذان مش هيظهر.',
                  ok: _notifications == true,
                  fixLabel: 'اسمح',
                  onFix: _fixNotifications,
                ),
                _CheckRow(
                  title: 'المنبهات الدقيقة',
                  detail: _exactAlarms == true
                      ? 'التطبيق يقدر يجدول الأذان في دقيقته.'
                      : 'مسموح بالجدولة التقريبية — ممكن يتأخر شوية.',
                  ok: _exactAlarms == true,
                  fixLabel: 'افتح الإعداد',
                  onFix: _fixExactAlarms,
                ),
                _CheckRow(
                  title: 'شاشة الأذان الكاملة',
                  detail: _fullScreen == true
                      ? 'الشاشة الكاملة مسموحة على القفل.'
                      : 'أندرويد 14 قافل الشاشة الكاملة — هيظهر إشعار عادي بدلها.',
                  ok: _fullScreen == true,
                  fixLabel: 'اسمح',
                  onFix: _fixFullScreen,
                ),
                _CheckRow(
                  title: 'استثناء البطارية',
                  detail: _battery == true
                      ? 'التطبيق مستثنى من تحسين البطارية.'
                      : 'النظام ممكن يوقف الأذان في الخلفية.',
                  ok: _battery == true,
                  fixLabel: 'اسمح',
                  onFix: _fixBattery,
                ),
                _CheckRow(
                  title: 'الطبقات فوق التطبيقات',
                  detail: _overlay == true
                      ? 'التطبيق يقدر يعرض كارت الأذان العائم.'
                      : 'اختياري — كارت الأذان العائم مش هيظهر.',
                  ok: _overlay == true,
                  fixLabel: 'اسمح',
                  onFix: _fixOverlay,
                ),
                _CheckRow(
                  title: 'قنوات الأصوات',
                  detail: _channelsCreated
                      ? 'قناة لكل صوت أذان بصوتها الصحيح.'
                      : 'مش اتأكدنا من القنوات.',
                  ok: _channelsCreated,
                  fixLabel: 'أنشئ',
                  onFix: _load,
                ),
                _CheckRow(
                  title: 'الأذان القادم',
                  detail: _nextPrayer == null
                      ? 'مفيش أذان مجدول. شغّل الأذان وحدّد موقعك.'
                      : _nextPrayerText(_nextPrayer!),
                  ok: _nextPrayer != null,
                  fixLabel: 'إعدادات الأذان',
                  onFix: () => context.push(ZakerRoutes.prayerNotifications),
                ),
                const SizedBox(height: ZakerSpacing.lg),
                const SectionHeader(
                  title: 'اختبارات',
                  icon: Icons.science_outlined,
                ),
                _TestCard(
                  icon: HugeIcons.strokeRoundedVolumeHigh,
                  title: 'جرّب الأذان دلوقتي',
                  subtitle: 'إشعار حقيقي بصوت الأذان المختار.',
                  busy: _testing,
                  onTap: _testAdhan,
                ),
                _TestCard(
                  icon: HugeIcons.strokeRoundedNotificationSnooze01,
                  title: 'اختبار إشعار بعد 10 ثواني',
                  subtitle: 'اقفل التطبيق واستنى — لو الإشعارات شغالة هيوصل.',
                  busy: _testing,
                  onTap: _testDelayed,
                ),
                const SizedBox(height: ZakerSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(ZakerSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: ZakerRadius.card,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: ZakerSpacing.sm),
                          const TrText(
                            ' لو الأذان مش بيوصل على شاومي / أوبو / هواوي',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TrText(
                        'افتح إعدادات الجهاز ← التطبيقات ← ذاكرلي، وفعّل '
                        '«التشغيل التلقائي» و«السماح بالتشغيل في الخلفية». '
                        'دي إعدادات خاصة بكل شركة ومش بتتفتح من التطبيق.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TrText(
                        'ولو غيّرت توقيت الجهاز أو منطقتك، افتح التطبيق مرة '
                        'عشان المواعيد والأذان يتظبطوا من جديد.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static String _nextPrayerText(({int id, String title, DateTime? when}) next) {
    final when = next.when;
    if (when == null) return next.title;
    final day = when.day.toString().padLeft(2, '0');
    final month = when.month.toString().padLeft(2, '0');
    return '${next.title} — $day/$month ${formatClockTime(when)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors});

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
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ZakerRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedWrench01,
                size: 23,
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
                  'خلّي الأذان يوصل في ميعاده',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                TrText(
                  'افحص كل شرط ومحتاجه على جهازك، وكل بند ليه زرار إصلاح.',
                  style: TextStyle(
                    color: Color(0xFFE7F8F6),
                    fontSize: 12,
                    height: 1.6,
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.detail,
    required this.ok,
    required this.fixLabel,
    required this.onFix,
  });

  final String title;
  final String detail;
  final bool ok;
  final String fixLabel;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final good = theme.brightness == Brightness.dark
        ? const Color(0xFF4ADE80)
        : const Color(0xFF166534);
    final bad = theme.brightness == Brightness.dark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);
    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: (ok ? good : bad).withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: ok ? good : bad,
            size: 20,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZakerSpacing.sm),
          if (!ok)
            TextButton(
              onPressed: onFix,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: TrText(
                fixLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final dynamic icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: ZakerRadius.card,
          child: Padding(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(ZakerRadius.md),
                  ),
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : HugeIcon(
                            icon: icon,
                            size: 19,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TrText(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
