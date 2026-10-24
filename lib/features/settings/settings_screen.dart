/// Settings and the account section.
///
/// The original app's settings group its entries under headings recovered
/// from the shipped strings — e.g. "2. أين تحفظ البيانات؟". Account and wallet
/// entries push their own screens. Every feature in the app is free: there is
/// no subscription screen, plan gate, or paywall.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notification_service.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final liveEnabled = ref.watch(liveEnabledProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          settings.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => data.isEmpty
                ? const SizedBox.shrink()
                : _RemoteSettingsCard(data: data),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(title: 'الحساب', icon: Icons.person_rounded),
          _Tile(
            icon: Icons.person_outline_rounded,
            title: 'حسابي',
            subtitle: 'اسمك وبياناتك والمزامنة',
            onTap: () => context.push(ZakerRoutes.account),
          ),
          _Tile(
            icon: Icons.wallet_rounded,
            title: 'المحفظة',
            subtitle: 'مدفوعاتك وميزانيتك',
            onTap: () => context.push(ZakerRoutes.wallet),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(title: 'التطبيق', icon: Icons.settings_rounded),
          _Tile(
            icon: Icons.notifications_outlined,
            title: 'المنبهات',
            subtitle: 'تذكير المذاكرة',
            onTap: () => _showReminders(context),
          ),
          _Tile(
            icon: Icons.auto_awesome_rounded,
            title: 'الأذكار والتنبيهات',
            subtitle: 'الصلاة على النبي وأذكار الصباح والمساء والكهف',
            onTap: () => context.push(ZakerRoutes.azkar),
          ),
          _Tile(
            icon: Icons.palette_outlined,
            title: 'تغيير الشكل',
            subtitle: 'الثيم وألوان التطبيق',
            onTap: () => context.push(ZakerRoutes.appearance),
          ),
          _Tile(
            icon: Icons.volume_up_outlined,
            title: 'الأصوات',
            subtitle: 'صوت الإنجاز',
            onTap: () => _showSounds(context),
          ),
          _Tile(
            icon: Icons.cloud_sync_outlined,
            title: 'المزامنة المباشرة',
            subtitle: liveEnabled
                ? 'شغالة — متصدرين وتحديات مشتركة'
                : 'متوقفة — شغّلها من الحساب',
            onTap: () => context.push(ZakerRoutes.account),
          ),
          _Tile(
            icon: Icons.language_rounded,
            title: 'اللغة',
            subtitle: locale.languageCode == 'en' ? 'English' : 'العربية',
            onTap: () => _showLanguage(context, ref),
          ),
          _Tile(
            icon: Icons.shield_outlined,
            title: 'الخصوصية',
            subtitle: 'أين تحفظ البيانات؟',
            onTap: () => _showPrivacy(context, ref),
          ),
          _Tile(
            icon: Icons.info_outline_rounded,
            title: 'عن ذاكرلي',
            subtitle: 'عن التطبيق',
            onTap: () => _showAbout(context),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          Center(
            child: TrText(
              'ذاكرلي — النسخة 1.1.0 (86)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The reminder switch and today's scheduled blocks.
  void _showReminders(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (_) => const _RemindersSheet(),
    );
  }

  /// The feedback-sound switch.
  void _showSounds(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final enabled = ref.watch(soundsEnabledProvider);
          return AlertDialog(
            title: const TrText('الأصوات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const TrText('صوت الإنجاز'),
                  subtitle: const TrText('نقرة قصيرة لما تجاوب أو تفتح هدف'),
                  value: enabled,
                  onChanged: (value) {
                    ref.read(soundsEnabledProvider.notifier).state = value;
                    if (value) {
                      SystemSound.play(SystemSoundType.click);
                    }
                  },
                ),
                TrText(
                  'الصوت بيشتغل على إجابات الاختبارات والأهداف.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const TrText('تمام'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The language dialog. Only Arabic ships a complete interface.
  void _showLanguage(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(localeProvider).languageCode;
          return AlertDialog(
            title: const TrText('اللغة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    current == 'ar'
                        ? Icons.check_circle_rounded
                        : Icons.language_rounded,
                  ),
                  title: const TrText('العربية'),
                  subtitle: current == 'ar'
                      ? const TrText('اللغة الحالية')
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).state = const Locale(
                      'ar',
                    );
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    current == 'en'
                        ? Icons.check_circle_rounded
                        : Icons.language_rounded,
                  ),
                  title: const Text('English'),
                  subtitle: current == 'en'
                      ? const TrText('اللغة الحالية')
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).state = const Locale(
                      'en',
                    );
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Where the study data lives, and what it contains.
  void _showPrivacy(BuildContext context, WidgetRef ref) {
    final stats = ref.read(studyStatsProvider);
    final notebooks = ref.read(notebooksProvider);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('الخصوصية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrText(
              'أين تحفظ البيانات؟',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            const TrText(
              'أهدافك ومهامك ودفاترك وكلماتك وسجل مذاكرتك بتتحفظ محليًا على '
              'جهازك. مفيش رفع تلقائي لحساب على السحابة.',
            ),
            const SizedBox(height: ZakerSpacing.md),
            _InfoRow(label: 'دقائق مسجلة', value: '${stats.totalMinutes}'),
            _InfoRow(label: 'دفاتر', value: '${notebooks.length}'),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              'أسئلة معلم AI بتبعت للسيرفر وقت ما تستخدم المحادثة بس.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('تمام'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ذاكرلي',
      applicationVersion: '1.1.0 (86)',
      applicationLegalese:
          'نسخة عربية للطلاب — مناهج، اختبارات، تركيز، ومعلم AI.',
      children: const [
        SizedBox(height: ZakerSpacing.md),
        TrText(
          'المناهج والصور محفوظة داخل التطبيق، فالقراءة شغالة من غير إنترنت.',
        ),
      ],
    );
  }
}

/// One label/value line inside the account and privacy dialogs.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: TrText(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TrText(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The reminder switch plus today's study blocks.
class _RemindersSheet extends ConsumerWidget {
  const _RemindersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationsEnabledProvider);
    final hour = ref.watch(reminderHourProvider);
    final minute = ref.watch(reminderMinuteProvider);
    final tasks = ref.watch(taskScheduleProvider).forDay();
    final timeLabel =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          0,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'المنبهات',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const TrText('تذكير المذاكرة'),
              subtitle: const TrText(
                'منبه يومي من النظام — بيظهر حتى لو التطبيق مقفول',
              ),
              value: enabled,
              onChanged: (value) async {
                ref.read(notificationsEnabledProvider.notifier).state = value;
                if (value) {
                  final ok = await NotificationService.instance.scheduleDaily(
                    hour: hour,
                    minute: minute,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: TrText(
                        ok
                            ? 'اتظبط منبه يومي الساعة $timeLabel 📚'
                            : 'مش قادر أجدول المنبه — راجع إذن الإشعارات.',
                      ),
                    ),
                  );
                } else {
                  await NotificationService.instance.cancelDaily();
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: enabled,
              leading: Icon(
                Icons.alarm_rounded,
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              title: const TrText('وقت التذكير'),
              subtitle: TrText(timeLabel),
              trailing: const Icon(Icons.edit_outlined),
              onTap: enabled
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (picked == null) return;
                      ref.read(reminderHourProvider.notifier).state =
                          picked.hour;
                      ref.read(reminderMinuteProvider.notifier).state =
                          picked.minute;
                      ref.read(notificationsEnabledProvider.notifier).state =
                          true;
                      final ok = await NotificationService.instance
                          .scheduleDaily(
                            hour: picked.hour,
                            minute: picked.minute,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: TrText(
                            ok
                                ? 'المنبه اليومي اتظبط على '
                                      '${picked.hour.toString().padLeft(2, '0')}:'
                                      '${picked.minute.toString().padLeft(2, '0')}'
                                : 'مش قادر أجدول المنبه — راجع إذن الإشعارات.',
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ZakerSpacing.md),
                child: TrText('مفيش مهام مجدولة النهارده.'),
              )
            else
              for (final task in tasks.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    task.done
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: task.done
                        ? ZakerColors.success
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: TrText(
                    task.title,
                    style: TextStyle(
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: task.dueAt == null
                      ? null
                      : TrText(
                          '${task.dueAt!.hour.toString().padLeft(2, '0')}:'
                          '${task.dueAt!.minute.toString().padLeft(2, '0')}',
                        ),
                ),
            const SizedBox(height: ZakerSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(ZakerRoutes.planner);
                },
                icon: const Icon(Icons.flag_rounded),
                label: const TrText('افتح أهداف اليوم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single settings row.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: TrText(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : TrText(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    );
  }
}

/// Shows the remote app-settings document returned by the backend.
class _RemoteSettingsCard extends StatelessWidget {
  const _RemoteSettingsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_done_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              TrText(
                'إعدادات من السيرفر',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          for (final e in data.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
              child: TrText(
                '${e.key}: ${e.value}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
