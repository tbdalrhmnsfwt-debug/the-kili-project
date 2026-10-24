/// The one-time Arabic explanation shown before the first location request.
///
/// It never blocks the app: every button — including dismissing the sheet —
/// leaves the user on a working home screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'location_flow.dart';
import 'prayer_providers.dart';

/// What the user tapped in the first-run sheet.
enum PrayerOnboardingChoice { device, city, later }

/// Shows the sheet once, then starts the chosen flow.
///
/// The sheet is marked as seen as soon as it closes, however it closes, so it
/// never appears twice.
Future<void> maybeShowPrayerOnboarding(
  BuildContext context,
  WidgetRef ref,
) async {
  final settingsController = ref.read(prayerSettingsProvider.notifier);
  if (ref.read(prayerSettingsProvider).onboarded) return;

  final choice = await showModalBottomSheet<PrayerOnboardingChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => const _PrayerOnboardingSheet(),
  );
  settingsController.markOnboarded();
  if (!context.mounted) return;

  switch (choice) {
    case PrayerOnboardingChoice.device:
      await startLocationFlow(context, ref);
    case PrayerOnboardingChoice.city:
      await chooseCity(context, ref);
    case PrayerOnboardingChoice.later:
    case null:
      break;
  }
}

class _PrayerOnboardingSheet extends StatelessWidget {
  const _PrayerOnboardingSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 2, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [ZakerColors.primary, ZakerColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ZakerColors.primary.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TrText(
              'مواقيت الصلاة في جيبك',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 8),
            TrText(
              'هنحسب مواقيت الصلاة الخمسة على جهازك حسب موقعك، '
              'والطريقة الافتراضية هي الهيئة المصرية العامة للمساحة. '
              'تقدر تغيّر طريقة الحساب ومذهب العصر في أي وقت.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.7,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            const _FeatureRow(
              icon: Icons.cloud_off_rounded,
              title: 'من غير إنترنت',
              subtitle: 'المواقيت تتحسب على جهازك، مفيش أي بيانات بتتبعت.',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.my_location_rounded,
              title: 'موقعك بيحدد الدقة',
              subtitle: 'هنطلب إذن الموقع عشان نعرف مدينتك، وبس.',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.tune_rounded,
              title: 'كل حاجة قابلة للتغيير',
              subtitle: 'طريقة الحساب، المذهب، والموقع — وقت ما تحب.',
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(PrayerOnboardingChoice.device),
              icon: const Icon(Icons.near_me_rounded, size: 19),
              label: const TrText('استخدم موقعي'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(PrayerOnboardingChoice.city),
              icon: const Icon(Icons.location_city_rounded, size: 19),
              label: const TrText('اختار مدينتي'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(PrayerOnboardingChoice.later),
              child: TrText(
                'بعدين',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TrText(
              'التطبيق شغال عادي حتى لو رفضت إذن الموقع — تقدر تختار مدينتك يدويًا.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.85,
                ),
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.20 : 0.09,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 11),
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
                    fontSize: 10.5,
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
