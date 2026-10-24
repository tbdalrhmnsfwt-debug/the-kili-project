/// The Friday Surat Al-Kahf reminder and a shortcut into the Quran reader.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/notification_service.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import '../quran/quran_reader_screen.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_widgets.dart';

class KahfScreen extends ConsumerWidget {
  const KahfScreen({super.key});

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final allowed = await NotificationService.instance.requestPermission();
      if (!context.mounted) return;
      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const TrText(
              'الإشعارات متقفلة للتطبيق. افتح إعدادات الجهاز وفعّلها الأول.',
            ),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () => AdhanPlatform.openAppSettings(),
            ),
          ),
        );
        return;
      }
    }
    final notifier = ref.read(azkarSettingsProvider.notifier);
    notifier.update(
      ref.read(azkarSettingsProvider).copyWith(kahfEnabled: enabled),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    AzkarSettings settings,
  ) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(azkarSettingsProvider);
    final now = DateTime.now();
    final isFriday = now.weekday == DateTime.friday;
    final time = formatClockMinutes(
      settings.kahfHour * 60 + settings.kahfMinute,
    );

    return Scaffold(
      appBar: AppBar(title: const TrText('سورة الكهف')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          AzkarHero(
            eyebrow: isFriday ? 'النهارده الجمعة' : 'كل جمعة',
            title: isFriday ? 'جمعة مباركة' : 'نور لجمعتك',
            subtitle: 'تذكير أسبوعي بقراءة سورة الكهف، وفتح مباشر من المصحف.',
            icon: HugeIcons.strokeRoundedBookOpen01,
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AzkarPill(
                  label: settings.kahfEnabled
                      ? 'التذكير شغال'
                      : 'التذكير متوقف',
                  icon: settings.kahfEnabled
                      ? HugeIcons.strokeRoundedNotification01
                      : HugeIcons.strokeRoundedNotificationSnooze01,
                  color: settings.kahfEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (settings.kahfEnabled)
                  AzkarPill(
                    label: 'كل جمعة $time',
                    icon: HugeIcons.strokeRoundedClock01,
                    color: ZakerColors.accent,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AzkarSurface(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? const <Color>[Color(0xFF1B2E2B), Color(0xFF1E293B)]
                  : const <Color>[Color(0xFFFFF8EA), Color(0xFFFFFDF8)],
            ),
            borderColor: ZakerColors.accent.withValues(alpha: 0.24),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: ZakerColors.accent.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ZakerColors.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedBookOpen01,
                      size: 29,
                      color: ZakerColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const TrText(
                  'سورة الكهف',
                  style: TextStyle(
                    fontFamily: ZakerTheme.fontQuran,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const QuranReaderScreen(initialSurahNumber: 18),
                        ),
                      );
                    },
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedBookOpen01,
                      size: 19,
                      color: Colors.white,
                    ),
                    label: const TrText('افتح سورة الكهف'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: ZakerColors.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AzkarSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: settings.kahfEnabled,
                  onChanged: (value) => _setEnabled(context, ref, value),
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedNotification01,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: const TrText(
                    'تذكير كل جمعة',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: const TrText(
                    'إشعار أسبوعي بقراءة سورة الكهف.',
                    style: TextStyle(fontSize: 10),
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
                  contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ZakerColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedClock01,
                        size: 20,
                        color: ZakerColors.accent,
                      ),
                    ),
                  ),
                  title: const TrText(
                    'وقت التذكير',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    '$time — ${isFriday ? 'النهارده' : 'كل جمعة'}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _pickTime(context, ref, settings),
                    child: const TrText('غيّر'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: TrText(
                  'التذكير بيتجدول مع مواقيت الصلاة ويفضل شغال بعد إعادة تشغيل الجهاز، حسب سماح النظام بالإشعارات الدقيقة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
