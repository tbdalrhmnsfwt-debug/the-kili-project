/// The full prayer-times screen: today's date, the next-prayer countdown, the
/// five prayers, and the current calculation and location settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/hijri_date.dart';
import '../../core/prayer_formats.dart';
import '../../core/prayer_methods.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'adhan_providers.dart';
import 'location_flow.dart';
import 'prayer_home_card.dart';
import 'prayer_models.dart';
import 'prayer_providers.dart';
import 'prayer_settings_sheet.dart';

class PrayerScreen extends ConsumerWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(prayerLocationProvider);
    final day = ref.watch(prayerDayProvider);
    final hijri = ref.watch(prayerHijriProvider);
    final settings = ref.watch(prayerSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'إشعارات الأذان',
            onPressed: () => context.push(ZakerRoutes.prayerNotifications),
            icon: const Icon(Icons.notifications_active_outlined, size: 22),
          ),
          IconButton(
            tooltip: 'تغيير الموقع',
            onPressed: () => showLocationPickerSheet(context, ref),
            icon: const Icon(Icons.edit_location_alt_outlined, size: 22),
          ),
          IconButton(
            tooltip: 'إعدادات الحساب',
            onPressed: () => showPrayerSettingsSheet(context),
            icon: const Icon(Icons.tune_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: location == null
              ? _NoLocationView(
                  settings: settings,
                  onDevice: () => startLocationFlow(context, ref),
                  onCity: () => chooseCity(context, ref),
                  onSettings: () => showPrayerSettingsSheet(context),
                )
              : day == null
              ? _CalculationErrorView(
                  onLocation: () => showLocationPickerSheet(context, ref),
                  onSettings: () => showPrayerSettingsSheet(context),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                  children: [
                    _DateHeader(
                      day: day,
                      hijri: hijri,
                      onLocation: () => showLocationPickerSheet(context, ref),
                    ),
                    const SizedBox(height: 14),
                    NextPrayerCard(
                      day: day,
                      hijri: hijri,
                      showMeta: false,
                      onLocation: () => showLocationPickerSheet(context, ref),
                    ),
                    const SizedBox(height: 20),
                    const _ListLabel(title: 'مواقيت اليوم'),
                    const SizedBox(height: 10),
                    for (var i = 0; i < day.prayers.length; i++) ...[
                      PrayerDetailTile(
                        prayer: day.prayers[i],
                        phase: day.phaseFor(i),
                        countdown: day.isNext(day.prayers[i].name)
                            ? formatCountdown(day.remaining)
                            : null,
                      ),
                      const SizedBox(height: 7),
                    ],
                    if (day.next.tomorrow) ...[
                      PrayerDetailTile(
                        prayer: day.next,
                        phase: PrayerPhase.next,
                        countdown: formatCountdown(day.remaining),
                      ),
                      const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 12),
                    _MethodCard(
                      method: prayerMethodById(settings.methodId),
                      madhab: prayerMadhabById(settings.madhabId),
                      onTap: () => showPrayerSettingsSheet(context),
                    ),
                    const SizedBox(height: 10),
                    _LocationCard(
                      location: day.location,
                      onTap: () => showLocationPickerSheet(context, ref),
                    ),
                    const SizedBox(height: 10),
                    const _AdhanCard(),
                    const SizedBox(height: 16),
                    const _Disclaimer(),
                  ],
                ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- date header

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.day,
    required this.hijri,
    required this.onLocation,
  });

  final PrayerDay day;
  final HijriDate hijri;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final location = day.location;
    final subtitle = location.subtitle;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.09),
            theme.cardTheme.color ?? theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.30 : 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    size: 21,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      hijri.formatted,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      formatGregorianDate(day.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TrText(
                        location.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: TrText(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    if (location.fromGps) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'GPS',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- main cards

class _ListLabel extends StatelessWidget {
  const _ListLabel({required this.title});

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

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.madhab,
    required this.onTap,
  });

  final PrayerMethodOption method;
  final PrayerMadhabOption madhab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
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
                    child: Icon(
                      Icons.calculate_outlined,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          'طريقة الحساب',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 1),
                        TrText(
                          method.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: theme.dividerTheme.color ?? Colors.black12,
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 46),
                  TrText(
                    'مذهب العصر',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                  const Spacer(),
                  TrText(
                    'مذهب ${madhab.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onTap});

  final PrayerLocation location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
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
                    icon: HugeIcons.strokeRoundedLocation01,
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
                      'الموقع',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      location.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${location.coordinatesText} · ${location.sourceLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TrText(
                'تغيير',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
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

class _AdhanCard extends ConsumerWidget {
  const _AdhanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(adhanSettingsProvider);
    final enabledPrayers = PrayerName.values
        .where(settings.isPrayerEnabled)
        .length;
    final subtitle = !settings.enabled
        ? 'مقفول — شغّل الأذان والتنبيهات'
        : settings.remindersEnabled
        ? 'شغال على $enabledPrayers من ٥ صلوات · تنبيه قبل الصلاة'
        : 'شغال على $enabledPrayers من ٥ صلوات';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(ZakerRoutes.prayerNotifications),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: settings.enabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.32)
                  : theme.dividerTheme.color ?? Colors.black12,
            ),
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
                    icon: settings.enabled
                        ? HugeIcons.strokeRoundedNotification01
                        : HugeIcons.strokeRoundedNotificationSnooze01,
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
                      'أذان الصلاة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: settings.enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TrText(
                'إعداد',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
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

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: TrText(
            'المواقيت محسوبة فلكيًا على جهازك حسب موقعك وطريقة الحساب '
            'المختارة، من غير إنترنت. ممكن تختلف دقائق بسيطة عن مسجدك — '
            'اتبع مواقيت المسجد عند الاختلاف.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- empty states

class _NoLocationView extends StatelessWidget {
  const _NoLocationView({
    required this.settings,
    required this.onDevice,
    required this.onCity,
    required this.onSettings,
  });

  final PrayerSettings settings;
  final VoidCallback onDevice;
  final VoidCallback onCity;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final method = prayerMethodById(settings.methodId);
    final madhab = prayerMadhabById(settings.madhabId);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [ZakerColors.primary, ZakerColors.primaryLight],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ZakerColors.primary.withValues(alpha: 0.32),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMosqueLocation,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TrText(
            'مواقيت الصلاة على جهازك',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          TrText(
            'حدد موقعك مرة واحدة، وهنحسب الخمس صلوات فلكيًا من غير '
            'إنترنت. التطبيق شغال عادي في كل الأحوال — تقدر تختار '
            'مدينتك يدويًا كمان.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.7,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDevice,
              icon: const Icon(Icons.near_me_rounded, size: 19),
              label: const TrText('حدد موقعي'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCity,
              icon: const Icon(Icons.location_city_rounded, size: 19),
              label: const TrText('اختار مدينتي'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.black12,
              ),
            ),
            child: Column(
              children: [
                _InfoLine(
                  icon: Icons.cloud_off_rounded,
                  label: 'الحساب بيتم على جهازك بدون إنترنت',
                ),
                const SizedBox(height: 9),
                _InfoLine(
                  icon: Icons.verified_user_outlined,
                  label: 'بيانات موقعك مش بتتسجل على أي سيرفر',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Divider(
                    height: 1,
                    color: theme.dividerTheme.color ?? Colors.black12,
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: TrText(
                            '${method.label} — مذهب ${madhab.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: TrText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalculationErrorView extends StatelessWidget {
  const _CalculationErrorView({
    required this.onLocation,
    required this.onSettings,
  });

  final VoidCallback onLocation;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 14),
            TrText(
              'مقدرناش نحسب المواقيت',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            TrText(
              'جرّب تغيّر الموقع أو طريقة الحساب، والمواقيت هتتحسب تاني '
              'على طول.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onLocation,
                    child: const TrText('تغيير الموقع'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSettings,
                    child: const TrText('طريقة الحساب'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
