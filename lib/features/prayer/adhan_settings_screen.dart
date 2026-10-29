/// Notification settings for the prayer feature.
///
/// * Master switch and the five per-prayer switches.
/// * A voice per prayer (Fajr has its own).
/// * An optional reminder a few minutes before each prayer.
/// * Readiness checks (notifications, exact alarms, battery optimisation) and
///   a "test now" button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/adhan_voices.dart';
import '../../core/notification_service.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'adhan_models.dart';
import 'adhan_providers.dart';
import 'adhan_scheduler.dart';
import 'adhan_voice_sheet.dart';
import 'prayer_models.dart';

class AdhanSettingsScreen extends ConsumerStatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  ConsumerState<AdhanSettingsScreen> createState() =>
      _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends ConsumerState<AdhanSettingsScreen>
    with WidgetsBindingObserver {
  bool? _notificationsAllowed;
  bool? _exactAllowed;
  bool? _ignoringBattery;
  bool? _fullScreenAllowed;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSystemState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSystemState();
  }

  Future<void> _refreshSystemState() async {
    final notifications =
        await NotificationService.instance.areNotificationsEnabled();
    final exact =
        await NotificationService.instance.canScheduleExactNotifications();
    final battery = await AdhanPlatform.isIgnoringBatteryOptimizations();
    final fullScreen = await AdhanPlatform.canUseFullScreenIntent();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = notifications;
      _exactAllowed = exact;
      _ignoringBattery = battery;
      _fullScreenAllowed = fullScreen ?? true;
    });
  }

  /// Explains why the runtime prompt is about to appear before showing it.
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

  Future<void> _setEnabled(bool value) async {
    final controller = ref.read(adhanSettingsProvider.notifier);
    if (!value) {
      controller.setEnabled(false);
      await _refreshSystemState();
      return;
    }

    if (!await _explainNotifications()) return;
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    if (!granted) {
      await _refreshSystemState();
      if (!mounted) return;
      _showSnack(
        'الإشعارات مقفولة. فعّلها للتطبيق من إعدادات النظام الأول.',
        actionLabel: 'الإعدادات',
        onAction: AdhanPlatform.openAppSettings,
      );
      return;
    }
    controller.setEnabled(true);
    await _refreshSystemState();
  }

  Future<void> _fixNotifications() async {
    var allowed = await NotificationService.instance.areNotificationsEnabled();
    if (!allowed && await _explainNotifications()) {
      allowed = await NotificationService.instance.requestPermission();
    }
    await _refreshSystemState();
    if (allowed) await _resync();
    if (!mounted || allowed) return;
    _showSnack(
      'لسه الإشعارات مقفولة — فعّلها من إعدادات النظام.',
      actionLabel: 'الإعدادات',
      onAction: AdhanPlatform.openAppSettings,
    );
  }

  Future<void> _fixExactAlarms() async {
    await NotificationService.instance.requestExactAlarmsPermission();
    await _refreshSystemState();
    // The earlier alarms were scheduled inexactly; rebuild them now that the
    // exact-alarm permission may have been granted.
    await _resync();
    if (!mounted) return;
    if (_exactAllowed == false) {
      _showSnack(
        'اسمح بـ«المنبهات والتذكيرات» في إعدادات النظام عشان الأذان '
        'يجي في وقته بالظبط.',
        actionLabel: 'الإعدادات',
        onAction: AdhanPlatform.openAppSettings,
      );
    }
  }

  /// Rebuilds the scheduled window after a permission change, ignoring a
  /// failure here because the settings screen has its own status indicators.
  Future<void> _resync() async {
    try {
      await ref.read(prayerAdhanSchedulerProvider).syncNow();
    } catch (_) {
      // Nothing to do: the readiness rows show the real platform state.
    }
  }

  Future<void> _openBattery() async {
    await context.push(ZakerRoutes.prayerBattery);
    await _refreshSystemState();
  }

  Future<void> _fixFullScreen() async {
    await AdhanPlatform.requestFullScreenIntentPermission();
    await _refreshSystemState();
    if (!mounted) return;
    if (_fullScreenAllowed == false) {
      _showSnack(
        'لسه الشاشة الكاملة مقفولة — اسمح للتطبيق من إعدادات أندرويد.',
        actionLabel: 'افتح التشخيص',
        onAction: () async {
          await context.push(ZakerRoutes.prayerDiagnostics);
        },
      );
    }
  }

  Future<void> _testAdhan() async {
    setState(() => _testing = true);
    final settings = ref.read(adhanSettingsProvider);
    final voice = adhanVoiceById(settings.voiceIdFor(PrayerName.dhuhr));
    final granted = await NotificationService.instance.requestPermission();
    final shown =
        granted && await NotificationService.instance.showTestAdhan(voice);
    if (!mounted) return;
    setState(() => _testing = false);
    _showSnack(
      shown
          ? 'اترسل إشعار تجريبي بصوت «${voice.title}».'
          : 'مش قادرين نبعت الإشعار — راجع صلاحية الإشعارات.',
    );
    await _refreshSystemState();
  }

  void _showSnack(
    String message, {
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: TrText(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: () {
                  onAction();
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(adhanSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText('أذان الصلاة')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              _MasterCard(enabled: settings.enabled, onChanged: _setEnabled),
              const SizedBox(height: 10),
              _StatusBarCard(
                value: settings.statusBarEnabled,
                onChanged: (value) => ref
                    .read(adhanSettingsProvider.notifier)
                    .setStatusBarEnabled(value),
              ),
              const SizedBox(height: 18),
              const _SectionLabel(title: 'جاهزية الأذان'),
              const SizedBox(height: 8),
              _ReadinessCard(
                notificationsAllowed: _notificationsAllowed,
                exactAllowed: _exactAllowed,
                ignoringBattery: _ignoringBattery,
                fullScreenAllowed: _fullScreenAllowed,
                onNotifications: _fixNotifications,
                onExact: _fixExactAlarms,
                onBattery: _openBattery,
                onFullScreen: _fixFullScreen,
              ),
              const SizedBox(height: 20),
              const _SectionLabel(title: 'الصلوات'),
              const SizedBox(height: 8),
              for (final prayer in PrayerName.values) ...[
                _PrayerCard(
                  prayer: prayer,
                  masterEnabled: settings.enabled,
                  enabled: settings.isPrayerEnabled(prayer),
                  voice: adhanVoiceById(settings.voiceIdFor(prayer)),
                  onChanged: (value) => ref
                      .read(adhanSettingsProvider.notifier)
                      .setPrayerEnabled(prayer, value),
                  onVoice: () => showAdhanVoiceSheet(context, prayer: prayer),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              const _SectionLabel(title: 'التنبيه المبكر'),
              const SizedBox(height: 8),
              _ReminderCard(
                settings: settings,
                onEnabled: (value) => ref
                    .read(adhanSettingsProvider.notifier)
                    .setRemindersEnabled(value),
                onMinutes: (minutes) => ref
                    .read(adhanSettingsProvider.notifier)
                    .setReminderMinutes(minutes),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(title: 'إسكات الأذان'),
              const SizedBox(height: 8),
              _HardwareSilenceCard(
                value: settings.silenceOnHardware,
                onChanged: (value) => ref
                    .read(adhanSettingsProvider.notifier)
                    .setSilenceOnHardware(value),
              ),
              const SizedBox(height: 20),
              _TestCard(
                voice: adhanVoiceById(settings.voiceIdFor(PrayerName.dhuhr)),
                testing: _testing,
                onTest: _testAdhan,
              ),
              const SizedBox(height: 14),
              TrText(
                'لو الأذان بيتأخر أو مش بييجي والتطبيق مقفول، راجع '
                '«تحسين البطارية» فوق — بعض الموبايلات بتوقف التطبيقات في '
                'الخلفية.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.85,
                  ),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              _CreditsTile(
                onTap: () => context.push(ZakerRoutes.prayerCredits),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- master card

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMosque01,
                size: 23,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'تشغيل الأذان',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  enabled
                      ? 'الأذان هيشتغل في الصلوات المفعّلة تحت.'
                      : 'شغّل المفتاح عشان تسمع الأذان في وقته.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- readiness

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.notificationsAllowed,
    required this.exactAllowed,
    required this.ignoringBattery,
    required this.fullScreenAllowed,
    required this.onNotifications,
    required this.onExact,
    required this.onBattery,
    required this.onFullScreen,
  });

  final bool? notificationsAllowed;
  final bool? exactAllowed;
  final bool? ignoringBattery;
  final bool? fullScreenAllowed;
  final VoidCallback onNotifications;
  final VoidCallback onExact;
  final VoidCallback onBattery;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        children: [
          _StatusRow(
            icon: HugeIcons.strokeRoundedNotification01,
            title: 'إشعارات النظام',
            subtitle: 'لازم تكون مسموحة عشان الأذان يظهر.',
            state: notificationsAllowed == null
                ? _CheckState.unknown
                : notificationsAllowed!
                    ? _CheckState.ok
                    : _CheckState.attention,
            statusText: notificationsAllowed == null
                ? '…'
                : notificationsAllowed!
                    ? 'مسموح'
                    : 'مقفول',
            onTap: onNotifications,
          ),
          const _Divider(),
          _StatusRow(
            icon: HugeIcons.strokeRoundedClock01,
            title: 'منبهات دقيقة',
            subtitle: 'من غيرها ممكن النظام يأخر الأذان شوية.',
            state: exactAllowed == null
                ? _CheckState.unknown
                : exactAllowed!
                    ? _CheckState.ok
                    : _CheckState.attention,
            statusText: exactAllowed == null
                ? '…'
                : exactAllowed!
                    ? 'مسموح'
                    : 'مش مسموح',
            onTap: onExact,
          ),
          const _Divider(),
          _StatusRow(
            icon: HugeIcons.strokeRoundedSmartPhone01,
            title: 'شاشة الأذان الكاملة',
            subtitle: 'عشان شاشة الأذان تفتح والموبايل مقفول (أندرويد 14+).',
            state: fullScreenAllowed == null
                ? _CheckState.unknown
                : fullScreenAllowed!
                    ? _CheckState.ok
                    : _CheckState.attention,
            statusText: fullScreenAllowed == null
                ? '…'
                : fullScreenAllowed!
                    ? 'مسموح'
                    : 'مقفول',
            onTap: onFullScreen,
          ),
          const _Divider(),
          _StatusRow(
            icon: HugeIcons.strokeRoundedBatteryCharging01,
            title: 'تحسين البطارية',
            subtitle: 'الاستثناء بيساعد الأذان يشتغل والتطبيق مقفول.',
            state: ignoringBattery == null
                ? _CheckState.unknown
                : ignoringBattery!
                    ? _CheckState.ok
                    : _CheckState.attention,
            statusText: ignoringBattery == null
                ? '…'
                : ignoringBattery!
                    ? 'مستثنى'
                    : 'شغال',
            onTap: onBattery,
          ),
        ],
      ),
    );
  }
}

enum _CheckState { ok, attention, unknown }

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.statusText,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final _CheckState state;
  final String statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      _CheckState.ok => ZakerColors.success,
      _CheckState.attention => ZakerColors.accent,
      _CheckState.unknown => theme.colorScheme.onSurfaceVariant,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: TrText(
                  statusText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- prayer cards

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.prayer,
    required this.masterEnabled,
    required this.enabled,
    required this.voice,
    required this.onChanged,
    required this.onVoice,
  });

  final PrayerName prayer;
  final bool masterEnabled;
  final bool enabled;
  final AdhanVoice voice;
  final ValueChanged<bool> onChanged;
  final VoidCallback onVoice;

  List<List<dynamic>> get _icon => switch (prayer) {
        PrayerName.fajr => HugeIcons.strokeRoundedSunrise,
        PrayerName.dhuhr => HugeIcons.strokeRoundedSun01,
        PrayerName.asr => HugeIcons.strokeRoundedSun03,
        PrayerName.maghrib => HugeIcons.strokeRoundedSunset,
        PrayerName.isha => HugeIcons.strokeRoundedMoon02,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = masterEnabled && enabled;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: masterEnabled ? 1 : 0.62,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 9, 8, 9),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: _icon,
                        size: 19,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          prayer.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 1),
                        TrText(
                          voice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: masterEnabled ? onChanged : null,
                  ),
                ],
              ),
            ),
            const _Divider(inset: 13),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                onTap: masterEnabled ? onVoice : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 9, 12, 9),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: active
                            ? HugeIcons.strokeRoundedVolumeHigh
                            : HugeIcons.strokeRoundedVolumeOff,
                        size: 17,
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TrText(
                          enabled
                              ? 'صوت: ${voice.title}'
                              : 'الصوت: ${voice.title} (المفتاح مقفول)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TrText(
                        'تغيير الصوت',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- hardware silencing

/// The default-on setting that lets the phone's own controls silence an adhan
/// that is playing.
class _HardwareSilenceCard extends StatelessWidget {
  const _HardwareSilenceCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedVolumeMute01,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'اكتم الأذان بأزرار الجهاز',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      'أزرار الصوت، وقفل الشاشة، وتغيير صوت المنبه من تطبيق تاني.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 6),
          TrText(
            'بعض أجهزة شاومي وأوبو بتقفل التحكم الكامل في أزرار الصوت أثناء '
            'الأذان؛ لو الزر مش بيسكت، استخدم زر الإيقاف في الشاشة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- status bar

class _StatusBarCard extends StatelessWidget {
  const _StatusBarCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedNotification02,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'شريط المواقيت الدائم',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 1),
                TrText(
                  'يعرض الصلاة القادمة والعد التنازلي في شريط الإشعارات، '
                  'حتى والتطبيق مقفول.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- reminders

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.settings,
    required this.onEnabled,
    required this.onMinutes,
  });

  final AdhanSettings settings;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification02,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'تنبيه قبل الأذان',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      'إشعار عادي قبل الصلاة بدقايق — من غير صوت الأذان.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: settings.remindersEnabled,
                onChanged: onEnabled,
              ),
            ],
          ),
          if (settings.remindersEnabled) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final minutes in kReminderMinutesOptions)
                    _MinuteChip(
                      minutes: minutes,
                      selected: settings.reminderMinutes == minutes,
                      onTap: () => onMinutes(minutes),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TrText(
            '$minutes د',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- test and credits

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.voice,
    required this.testing,
    required this.onTest,
  });

  final AdhanVoice voice;
  final bool testing;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: testing ? null : onTest,
              icon: testing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedVolumeHigh,
                      size: 19,
                      color: theme.colorScheme.onPrimary,
                    ),
              label: const TrText('جرّب الأذان الآن'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
          const SizedBox(height: 7),
          TrText(
            'هيتبعت إشعار حقيقي بصوت «${voice.title}» عشان تتأكد إن كل '
            'حاجة شغالة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsTile extends StatelessWidget {
  const _CreditsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMusicNote02,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'حول / التراخيص',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      'بيانات الإسناد المطلوبة قانونيًا للتسجيلات.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                size: 19,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- misc

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

class _Divider extends StatelessWidget {
  const _Divider({this.inset = 0});

  final double inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Divider(
        height: 1,
        color: theme.dividerTheme.color ?? Colors.black12,
      ),
    );
  }
}
