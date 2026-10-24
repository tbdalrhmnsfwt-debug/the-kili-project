/// The permission/location flow used by the first-run sheet, the home card and
/// the prayer screen.
///
/// The flow is deliberately forgiving: a disabled location service, a denied
/// permission, a missing GPS fix or a device without a geocoder all lead to
/// the city picker instead of a dead end.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'location_picker_sheet.dart';
import 'prayer_models.dart';
import 'prayer_providers.dart';
import 'prayer_service.dart';

/// Asks for the device location, saving it when successful.
///
/// Returns the saved location, or `null` when the user cancelled or a fallback
/// was used.  In every failure path the user is offered the city picker; the
/// app never waits on the permission dialog to be usable.
Future<PrayerLocation?> startLocationFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final settingsController = ref.read(prayerSettingsProvider.notifier);
  final locationController = ref.read(prayerLocationProvider.notifier);
  settingsController.markOnboarded();

  bool? serviceEnabled;
  try {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
  } catch (error) {
    debugPrint('prayer: location service check failed ($error)');
  }
  if (!context.mounted) return null;
  if (serviceEnabled == null) {
    // The location plugin is unavailable (for example a platform without the
    // plugin registered). Go straight to the offline list.
    return chooseCity(context, ref);
  }
  if (!serviceEnabled) {
    final action = await _showProblemDialog(context, _Problem.serviceOff);
    if (!context.mounted) return null;
    if (action == _ProblemAction.city) return chooseCity(context, ref);
    if (action == _ProblemAction.settings) {
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {
        // Nothing else to do; the user can still pick a city.
      }
      if (context.mounted) {
        _message(context, 'فعّل خدمة الموقع، وبعدين جرّب «حدد موقعي» تاني.');
      }
    }
    return null;
  }

  LocationPermission? permission;
  try {
    permission = await Geolocator.checkPermission();
  } catch (error) {
    debugPrint('prayer: permission check failed ($error)');
  }
  if (!context.mounted) return null;
  if (permission == null) return chooseCity(context, ref);

  if (permission == LocationPermission.denied) {
    try {
      permission = await Geolocator.requestPermission();
    } catch (error) {
      debugPrint('prayer: permission request failed ($error)');
      permission = LocationPermission.denied;
    }
  }
  if (!context.mounted) return null;

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever ||
      permission == LocationPermission.unableToDetermine) {
    final action = await _showProblemDialog(
      context,
      permission == LocationPermission.deniedForever
          ? _Problem.permissionForever
          : _Problem.permissionDenied,
    );
    if (!context.mounted) return null;
    if (action == _ProblemAction.city) return chooseCity(context, ref);
    if (action == _ProblemAction.settings) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {
        // Ignore: the city picker below is the guaranteed path.
      }
      return null;
    }
    return null;
  }

  Position? position;
  _message(context, 'بنجيب موقعك الحالي…');
  try {
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 30),
      ),
    );
  } catch (error) {
    debugPrint('prayer: could not read the GPS position ($error)');
  }
  if (!context.mounted) return null;
  if (position == null) {
    _message(context, 'مقدرناش نحدد موقعك دلوقتي. اختار مدينتك من القائمة.');
    return chooseCity(context, ref);
  }

  final location = await locationFromPosition(position);
  await locationController.save(location);
  settingsController.markOnboarded();
  if (context.mounted) {
    _message(context, 'تم تحديد موقعك: ${location.displayName}');
  }
  return location;
}

/// Opens the picker and saves the chosen city (or manual coordinates).
Future<PrayerLocation?> chooseCity(BuildContext context, WidgetRef ref) async {
  final locationController = ref.read(prayerLocationProvider.notifier);
  final settingsController = ref.read(prayerSettingsProvider.notifier);
  final current = ref.read(prayerLocationProvider);
  final location = await showCityPicker(context, current: current);
  if (location == null) return null;
  settingsController.markOnboarded();
  await locationController.save(location);
  if (context.mounted) {
    _message(context, 'تم حفظ الموقع: ${location.displayName}');
  }
  return location;
}

/// A small action sheet for changing the saved location.
Future<void> showLocationPickerSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final action = await showModalBottomSheet<_LocationAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => const _LocationActionSheet(),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case _LocationAction.device:
      await startLocationFlow(context, ref);
    case _LocationAction.city:
      await chooseCity(context, ref);
    case _LocationAction.manual:
      final initial = ref.read(prayerLocationProvider);
      final location = await showManualCoordinatesDialog(
        context,
        initial: initial,
      );
      if (!context.mounted || location == null) return;
      await ref.read(prayerLocationProvider.notifier).save(location);
      if (context.mounted) {
        _message(context, 'تم حفظ الموقع: ${location.displayName}');
      }
  }
}

/// Refreshes a GPS-derived location when the device has moved more than
/// [thresholdMetres] since it was saved.
///
/// The last-known fix is used as a cheap first check; only a likely move is
/// confirmed with one low-accuracy GPS fix.  Any failure is ignored so the UI
/// keeps working with the previous location.
Future<void> refreshLocationIfMoved(
  WidgetRef ref, {
  double thresholdMetres = 10000,
}) async {
  final current = ref.read(prayerLocationProvider);
  final locationController = ref.read(prayerLocationProvider.notifier);
  if (current == null || !current.fromGps) return;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return;
    }
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown == null) return;
    if (_distanceMetres(current, lastKnown) < thresholdMetres) return;

    // The cached fix can be stale, so confirm with one low-accuracy fix before
    // treating this as a real move.
    Position? confirmed;
    try {
      confirmed = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (error) {
      debugPrint('prayer: move confirmation failed ($error)');
    }
    if (confirmed == null) return;
    if (_distanceMetres(current, confirmed) < thresholdMetres) return;

    final updated = await locationFromPosition(confirmed);
    await locationController.save(updated);
  } catch (error) {
    debugPrint('prayer: movement check skipped ($error)');
  }
}

double _distanceMetres(PrayerLocation location, Position position) {
  final metres = Geolocator.distanceBetween(
    location.latitude,
    location.longitude,
    position.latitude,
    position.longitude,
  );
  return metres.isFinite ? metres : 0;
}

void _message(BuildContext context, String text) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: TrText(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}

enum _Problem { serviceOff, permissionDenied, permissionForever }

enum _ProblemAction { city, settings, later }

Future<_ProblemAction?> _showProblemDialog(
  BuildContext context,
  _Problem problem,
) {
  final theme = Theme.of(context);
  final isService = problem == _Problem.serviceOff;
  final isForever = problem == _Problem.permissionForever;
  final title = isService
      ? 'خدمة الموقع مقفولة'
      : isForever
      ? 'إذن الموقع مقفول'
      : 'محتاجين إذن الموقع';
  final body = isService
      ? 'فعّل خدمة الموقع من إعدادات الجهاز عشان نحدد مدينتك تلقائيًا. '
            'وتقدر تختار مدينتك يدويًا من القائمة، والتطبيق شغال عادي.'
      : isForever
      ? 'إذن الموقع متقفل في إعدادات التطبيق. افتح الإعدادات واسمح بالوصول، '
            'أو اختار مدينتك يدويًا — المواقيت هتتحسب صح في الحالتين.'
      : 'لو مش عايز تسمح بالموقع، مفيش مشكلة: اختار مدينتك من القائمة '
            'وهنحسب المواقيت على جهازك بدون إنترنت.';
  final settingsLabel = isService ? 'إعدادات الموقع' : 'إعدادات التطبيق';

  return showDialog<_ProblemAction>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isService
                ? Icons.location_off_rounded
                : Icons.not_listed_location_rounded,
            size: 27,
            color: theme.colorScheme.primary,
          ),
        ),
        title: TrText(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: TrText(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.7,
          ),
        ),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ProblemAction.later),
            child: const TrText('بعدين'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ProblemAction.settings),
            child: TrText(settingsLabel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ProblemAction.city),
            child: const TrText('اختار مدينتي'),
          ),
        ],
      );
    },
  );
}

enum _LocationAction { device, city, manual }

class _LocationActionSheet extends StatelessWidget {
  const _LocationActionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: TrText(
              'موقع الصلاة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _LocationOption(
            icon: HugeIcons.strokeRoundedLocation01,
            title: 'موقعي الحالي',
            subtitle: 'نحدد مدينتك بالـ GPS وبنحدّثها لو سافرت',
            onTap: () => Navigator.of(context).pop(_LocationAction.device),
          ),
          const SizedBox(height: 6),
          _LocationOption(
            icon: HugeIcons.strokeRoundedMosqueLocation,
            title: 'اختار مدينة',
            subtitle: 'كل محافظات مصر — من غير إنترنت',
            onTap: () => Navigator.of(context).pop(_LocationAction.city),
          ),
          const SizedBox(height: 6),
          _LocationOption(
            icon: HugeIcons.strokeRoundedCompass,
            title: 'إحداثيات يدوية',
            subtitle: 'لو عندك خط العرض والطول',
            onTap: () => Navigator.of(context).pop(_LocationAction.manual),
          ),
        ],
      ),
    );
  }
}

class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    size: 21,
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
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    TrText(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
