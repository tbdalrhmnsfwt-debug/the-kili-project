/// Settings for the salat reminders, morning/evening azkar and Friday Kahf.
///
/// Every feature has its own switch.  The screen also shows the real Android
/// readiness state (notifications, exact alarms, battery optimisation), sends
/// test notifications, and keeps the required attribution in one small About /
/// Licenses entry at the very bottom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/notification_service.dart';
import '../../core/router.dart';
import '../../core/salat_audio.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import '../prayer/prayer_providers.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_widgets.dart';

class AzkarSettingsScreen extends ConsumerStatefulWidget {
  const AzkarSettingsScreen({super.key});

  @override
  ConsumerState<AzkarSettingsScreen> createState() =>
      _AzkarSettingsScreenState();
}

class _AzkarSettingsScreenState extends ConsumerState<AzkarSettingsScreen>
    with WidgetsBindingObserver {
  bool? _notifications;
  bool? _exact;
  bool? _battery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notifications = await NotificationService.instance
        .areNotificationsEnabled();
    final exact = await NotificationService.instance
        .canScheduleExactNotifications();
    final battery = await AdhanPlatform.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _exact = exact;
      _battery = battery;
    });
  }

  Future<bool> _ensureNotifications() async {
    if (await NotificationService.instance.areNotificationsEnabled()) {
      return true;
    }
    final granted = await NotificationService.instance.requestPermission();
    await _refresh();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const TrText(
            'الإشعارات مقفولة. اسمح بيها من إعدادات الجهاز عشان التذكيرات توصل.',
          ),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: () => AdhanPlatform.openAppSettings(),
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _apply(AzkarSettings next, {required bool enabling}) async {
    if (enabling && !await _ensureNotifications()) return;
    ref.read(azkarSettingsProvider.notifier).update(next);
  }

  Future<void> _requestExact() async {
    await NotificationService.instance.requestExactAlarmsPermission();
    await _refresh();
  }

  Future<void> _requestNotifications() async {
    await NotificationService.instance.requestPermission();
    if (!mounted) return;
    await _refresh();
    if (_notifications != true && mounted) {
      await AdhanPlatform.openAppSettings();
    }
  }

  Future<void> _pickWindowTime({required bool start}) async {
    final settings = ref.read(azkarSettingsProvider);
    final minutes = start
        ? settings.salatStartMinutes
        : settings.salatEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
      helpText: start ? 'بداية وقت التذكير' : 'نهاية وقت التذكير',
      cancelText: 'إلغاء',
      confirmText: 'تمام',
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    final current = ref.read(azkarSettingsProvider);
    ref
        .read(azkarSettingsProvider.notifier)
        .update(
          current.copyWith(
            salatStartMinutes: start ? value : current.salatStartMinutes,
            salatEndMinutes: start ? current.salatEndMinutes : value,
          ),
        );
  }

  Future<void> _pickKahfTime() async {
    final settings = ref.read(azkarSettingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.kahfHour,
        minute: settings.kahfMinute,
      ),
      helpText: 'وقت تذكير سورة الكهف',
      cancelText: 'إلغاء',
      confirmText: 'تمام',
    );
    if (picked == null) return;
    ref
        .read(azkarSettingsProvider.notifier)
        .update(
          ref
              .read(azkarSettingsProvider)
              .copyWith(kahfHour: picked.hour, kahfMinute: picked.minute),
        );
  }

  void _togglePhrase(String id, bool selected) {
    final settings = ref.read(azkarSettingsProvider);
    final ids = Set<String>.of(settings.selectedPhraseIds);
    if (selected) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('اختار صيغة واحدة على الأقل للصلاة على النبي.'),
        ),
      );
      return;
    }
    ref
        .read(azkarSettingsProvider.notifier)
        .update(
          settings.copyWith(selectedPhraseIds: Set<String>.unmodifiable(ids)),
        );
  }

  void _setSound(String phraseId, SalatSoundMode mode) {
    final settings = ref.read(azkarSettingsProvider);
    final sounds = Map<String, SalatSoundMode>.of(settings.phraseSounds);
    sounds[phraseId] = mode;
    ref
        .read(azkarSettingsProvider.notifier)
        .update(
          settings.copyWith(
            phraseSounds: Map<String, SalatSoundMode>.unmodifiable(sounds),
          ),
        );
  }

  Future<void> _sendSalatTest(AzkarSettings settings) async {
    final phrases = settings.selectedPhrases;
    if (phrases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('اختار صيغة واحدة على الأقل الأول.')),
      );
      return;
    }
    if (!await _ensureNotifications()) return;
    final phrase = phrases.first;
    final sent = await NotificationService.instance.showTestSalat(
      phrase: phrase,
      sound: settings.soundFor(phrase.id),
      vibration: settings.salatVibration,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TrText(
          sent
              ? 'بعتنا التذكير — شوف الإشعار فوق.'
              : 'مش قادرين نبعت الإشعار دلوقتي. جرّب تاني.',
        ),
      ),
    );
  }

  Future<void> _sendAzkarTest() async {
    if (!await _ensureNotifications()) return;
    final sent = await NotificationService.instance.showTestAzkar(
      body: 'وقت أذكار الصباح — افتح واقرأ وعدّ.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TrText(
          sent
              ? 'بعتنا إشعار أذكار الصباح — العنوان: اذكار الصباح.'
              : 'مش قادرين نبعت الإشعار دلوقتي. جرّب تاني.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(azkarSettingsProvider);
    final location = ref.watch(prayerLocationProvider);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const TrText('تنبيهات الأذكار')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const AzkarHero(
            eyebrow: 'تحكم كامل',
            title: 'خلي ذكرك معاك',
            subtitle: 'فاصل الصلاة على النبي، وقت أذكار الصباح والمساء، وتذكير الجمعة — كل حاجة لوحدها.',
            icon: HugeIcons.strokeRoundedSettings01,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
          ),
          const SizedBox(height: 16),
          _ReadinessCard(
            notifications: _notifications,
            exact: _exact,
            battery: _battery,
            onRequestNotifications: _requestNotifications,
            onRequestExact: _requestExact,
            onOpenBattery: () => context.push(ZakerRoutes.prayerBattery),
          ),
          const SizedBox(height: 22),
          const AzkarSectionHeader(
            title: 'الصلاة على النبي',
            subtitle: 'تذكير منتظم بالصيغة اللي تختارها',
            icon: HugeIcons.strokeRoundedStar,
          ),
          const SizedBox(height: 10),
          AzkarSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: settings.salatEnabled,
                  onChanged: (value) => _apply(
                    settings.copyWith(salatEnabled: value),
                    enabling: value,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
                  secondary: _IconBox(
                    icon: HugeIcons.strokeRoundedStar,
                    color: ZakerColors.accent,
                  ),
                  title: const TrText(
                    'تذكير الصلاة على النبي',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const TrText(
                    'شغّله واختار الفاصل والوقت والصيغ.',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
                const _CardDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel(
                        label: 'الفاصل',
                        icon: HugeIcons.strokeRoundedClock01,
                      ),
                      const SizedBox(height: 8),
                      _ChipGroup<int>(
                        values: kSalatIntervals,
                        selected: settings.salatIntervalMinutes,
                        label: (value) => 'كل ${_arabicNumber(value)} دقيقة',
                        onChanged: (value) => ref
                            .read(azkarSettingsProvider.notifier)
                            .update(
                              settings.copyWith(salatIntervalMinutes: value),
                            ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel(
                        label: 'وقت التذكير',
                        icon: HugeIcons.strokeRoundedSun03,
                      ),
                      const SizedBox(height: 8),
                      _ChipGroup<SalatWindow>(
                        values: SalatWindow.values,
                        selected: settings.salatWindow,
                        label: (value) => value.label,
                        onChanged: (value) => ref
                            .read(azkarSettingsProvider.notifier)
                            .update(
                              ref
                                  .read(azkarSettingsProvider)
                                  .copyWith(salatWindow: value),
                            ),
                      ),
                      if (settings.salatWindow == SalatWindow.custom) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeButton(
                                label: 'من',
                                value: formatClockMinutes(
                                  settings.salatStartMinutes,
                                ),
                                onTap: () => _pickWindowTime(start: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TimeButton(
                                label: 'لـ',
                                value: formatClockMinutes(
                                  settings.salatEndMinutes,
                                ),
                                onTap: () => _pickWindowTime(start: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'لو النهاية قبل البداية، الفترة بتكمل بعد منتصف الليل.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                            fontSize: 9,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _FieldLabel(
                        label: 'الصيغ',
                        icon: HugeIcons.strokeRoundedMusicNote02,
                      ),
                      const SizedBox(height: 8),
                      for (final phrase in kSalatPhrases) ...[
                        _PhraseSetting(
                          phrase: phrase,
                          selected: settings.isPhraseSelected(phrase.id),
                          sound: settings.soundFor(phrase.id),
                          hasRecording: SalatAudioCatalog.instance.hasRecording(
                            phrase.id,
                          ),
                          onSelected: (value) =>
                              _togglePhrase(phrase.id, value),
                          onSound: (mode) => _setSound(phrase.id, mode),
                        ),
                        if (phrase != kSalatPhrases.last)
                          const SizedBox(height: 8),
                      ],
                      if (kSalatPhrases.any(
                        (phrase) =>
                            SalatAudioCatalog.instance.hasRecording(phrase.id),
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'التسجيل المضاف في assets بيتشغّل من شاشة الذكر. '
                            'صوت الإشعار المباشر محتاج نسخة raw، وإلا الإشعار بيظهر نص وصامت.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 9,
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      SwitchListTile.adaptive(
                        value: settings.salatVibration,
                        onChanged: (value) => ref
                            .read(azkarSettingsProvider.notifier)
                            .update(
                              ref
                                  .read(azkarSettingsProvider)
                                  .copyWith(salatVibration: value),
                            ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const TrText(
                          'اهتزاز مع التذكير',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        secondary: Icon(
                          Icons.vibration_rounded,
                          size: 20,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const AzkarSectionHeader(
            title: 'أذكار الصباح والمساء',
            subtitle: 'التنبيه بيتحسب من مواقيت موقعك',
            icon: HugeIcons.strokeRoundedSunrise,
          ),
          const SizedBox(height: 10),
          if (location == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AzkarSurface(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderColor: ZakerColors.accent.withValues(alpha: 0.30),
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: ZakerColors.accent,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: TrText(
                        'محتاجين موقعك عشان نحسب الفجر والعصر. اختاره من صفحة الصلاة.',
                        style: TextStyle(fontSize: 10, height: 1.5),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(ZakerRoutes.prayer),
                      child: const TrText('حدد'),
                    ),
                  ],
                ),
              ),
            ),
          _AzkarPeriodCard(
            title: 'أذكار الصباح',
            subtitle: 'بعد الفجر',
            icon: HugeIcons.strokeRoundedSunrise,
            enabled: settings.morningEnabled,
            offset: settings.morningOffsetMinutes,
            color: primary,
            onEnabled: (value) => _apply(
              settings.copyWith(morningEnabled: value),
              enabling: value,
            ),
            onOffset: (value) => ref
                .read(azkarSettingsProvider.notifier)
                .update(
                  ref
                      .read(azkarSettingsProvider)
                      .copyWith(morningOffsetMinutes: value),
                ),
          ),
          const SizedBox(height: 10),
          _AzkarPeriodCard(
            title: 'أذكار المساء',
            subtitle: 'بعد العصر',
            icon: HugeIcons.strokeRoundedMoon02,
            enabled: settings.eveningEnabled,
            offset: settings.eveningOffsetMinutes,
            color: ZakerColors.accent,
            onEnabled: (value) => _apply(
              settings.copyWith(eveningEnabled: value),
              enabling: value,
            ),
            onOffset: (value) => ref
                .read(azkarSettingsProvider.notifier)
                .update(
                  ref
                      .read(azkarSettingsProvider)
                      .copyWith(eveningOffsetMinutes: value),
                ),
          ),
          const SizedBox(height: 22),
          const AzkarSectionHeader(
            title: 'سورة الكهف',
            subtitle: 'تذكير أسبوعي يوم الجمعة',
            icon: HugeIcons.strokeRoundedBookOpen01,
          ),
          const SizedBox(height: 10),
          AzkarSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: settings.kahfEnabled,
                  onChanged: (value) => _apply(
                    settings.copyWith(kahfEnabled: value),
                    enabling: value,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
                  secondary: const _IconBox(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    color: ZakerColors.accent,
                  ),
                  title: const TrText(
                    'تذكير سورة الكهف',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const TrText(
                    'إشعار كل جمعة في الوقت اللي تختاره.',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
                const _CardDivider(),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
                  leading: _IconBox(
                    icon: HugeIcons.strokeRoundedClock01,
                    color: primary,
                  ),
                  title: const TrText(
                    'وقت تذكير الجمعة',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  subtitle: Text(
                    formatClockMinutes(
                      settings.kahfHour * 60 + settings.kahfMinute,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _pickKahfTime,
                    child: const TrText('غيّر'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AzkarSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const AzkarSectionHeader(
                  title: 'جرّب قبل ما تعتمد',
                  subtitle: 'هنبعت إشعار حقيقي بنفس القناة والصوت.',
                  icon: HugeIcons.strokeRoundedNotification01,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _sendSalatTest(ref.read(azkarSettingsProvider)),
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      size: 19,
                    ),
                    label: const TrText('ابعت تذكير الصلاة على النبي'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sendAzkarTest,
                  child: const TrText('جرّب إشعار أذكار الصباح'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AzkarSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              onTap: () => context.push(ZakerRoutes.azkarLicenses),
              contentPadding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
              leading: _IconBox(
                icon: HugeIcons.strokeRoundedLicense,
                color: muted,
              ),
              title: const TrText(
                'حول والتراخيص',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              subtitle: const TrText(
                'مصادر الأصوات والملفات المرفقة.',
                style: TextStyle(fontSize: 9),
              ),
              trailing: const Icon(Icons.chevron_left_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.do_not_disturb_on_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'وضع عدم الإزعاج بيتحترم من نظام التشغيل. '
                  'التذكيرات بتتعاد جدولتها مع مواقيت الصلاة وبعد إعادة تشغيل الجهاز.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontSize: 9,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.notifications,
    required this.exact,
    required this.battery,
    required this.onRequestNotifications,
    required this.onRequestExact,
    required this.onOpenBattery,
  });

  final bool? notifications;
  final bool? exact;
  final bool? battery;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestExact;
  final VoidCallback onOpenBattery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return AzkarSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _ReadinessRow(
            icon: HugeIcons.strokeRoundedNotification01,
            title: 'إشعارات النظام',
            ok: notifications,
            okText: 'مسموح',
            problemText: 'مقفولة',
            onFix: onRequestNotifications,
          ),
          const _CardDivider(),
          _ReadinessRow(
            icon: HugeIcons.strokeRoundedClock01,
            title: 'التنبيهات الدقيقة',
            ok: exact,
            okText: 'مضمونة',
            problemText: 'قد تتأخر',
            onFix: onRequestExact,
          ),
          const _CardDivider(),
          _ReadinessRow(
            icon: HugeIcons.strokeRoundedBatteryCharging01,
            title: 'استثناء البطارية',
            ok: battery,
            okText: 'مستثنى',
            problemText: 'ممكن يتوقف',
            onFix: onOpenBattery,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 13,
                color: primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: TrText(
                  'الجدولة بتشتغل من غير إنترنت وبتتجدّد مع الفجر والعصر.',
                  style: TextStyle(fontSize: 9, height: 1.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okText,
    required this.problemText,
    required this.onFix,
  });

  final List<List<dynamic>> icon;
  final String title;
  final bool? ok;
  final String okText;
  final String problemText;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final good = ok == true;
    final unknown = ok == null;
    final color = good
        ? ZakerColors.success
        : unknown
        ? theme.colorScheme.onSurfaceVariant
        : ZakerColors.danger;
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: HugeIcon(
            icon: icon,
            size: 17,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TrText(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            unknown
                ? '…'
                : good
                ? okText
                : problemText,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (!good && !unknown) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              minimumSize: const Size(38, 30),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const TrText(
              'إصلاح',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

class _AzkarPeriodCard extends StatelessWidget {
  const _AzkarPeriodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.offset,
    required this.color,
    required this.onEnabled,
    required this.onOffset,
  });

  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final bool enabled;
  final int offset;
  final Color color;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<int> onOffset;

  @override
  Widget build(BuildContext context) {
    return AzkarSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: enabled,
            onChanged: onEnabled,
            contentPadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
            secondary: _IconBox(icon: icon, color: color),
            title: TrText(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: TrText(
              enabled
                  ? '$subtitle — التذكير شغال'
                  : '$subtitle — التذكير متوقف',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          if (enabled) ...[
            const _CardDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel(
                    label: 'بعد موعد الصلاة',
                    icon: HugeIcons.strokeRoundedClock01,
                  ),
                  const SizedBox(height: 8),
                  _ChipGroup<int>(
                    values: kAzkarOffsetOptions,
                    selected: offset,
                    label: (value) =>
                        value == 0 ? 'فورًا' : '${_arabicNumber(value)} دقيقة',
                    onChanged: onOffset,
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

class _PhraseSetting extends StatelessWidget {
  const _PhraseSetting({
    required this.phrase,
    required this.selected,
    required this.sound,
    required this.hasRecording,
    required this.onSelected,
    required this.onSound,
  });

  final SalatPhrase phrase;
  final bool selected;
  final SalatSoundMode sound;
  final bool hasRecording;
  final ValueChanged<bool> onSelected;
  final ValueChanged<SalatSoundMode> onSound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: selected
            ? primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.15 : 0.045,
              )
            : muted.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? primary.withValues(alpha: 0.28)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: selected,
                  onChanged: (value) => onSelected(value ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(!selected),
                  child: Text(
                    phrase.text,
                    style: TextStyle(
                      fontFamily: ZakerTheme.fontQuran,
                      fontSize: 14,
                      height: 1.7,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                'الصوت',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final mode in SalatSoundMode.values)
                      Tooltip(
                        message: mode == SalatSoundMode.voice && !hasRecording
                            ? 'مفيش تسجيل مرفق للصيغة دي'
                            : switch (mode) {
                                SalatSoundMode.voice => 'تشغيل التسجيل',
                                SalatSoundMode.chime => 'نغمة قصيرة',
                                SalatSoundMode.silent => 'من غير صوت',
                              },
                        child: ChoiceChip(
                          selected: sound == mode,
                          onSelected:
                              mode == SalatSoundMode.voice && !hasRecording
                              ? null
                              : (_) => onSound(mode),
                          showCheckmark: false,
                          label: Text(
                            switch (mode) {
                              SalatSoundMode.voice => 'صوت',
                              SalatSoundMode.chime => 'نغمة',
                              SalatSoundMode.silent => 'صامت',
                            },
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasRecording)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 13,
                    color: ZakerColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in values)
          ChoiceChip(
            selected: value == selected,
            onSelected: (_) => onChanged(value),
            showCheckmark: false,
            label: Text(label(value)),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            labelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.icon});

  final String label;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        TrText(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final List<List<dynamic>> icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        child: HugeIcon(icon: icon, size: 19, color: color),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 14,
      endIndent: 14,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.4),
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
