/// Settings and the account section.
///
/// The original app's settings group its entries under headings recovered
/// from the shipped strings — e.g. "2. أين تحفظ البيانات؟",
/// "4. الاشتراكات والمدفوعات" — and links out to
/// `play.google.com/store/account/subscriptions?package=com.zakerly.ai`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Where the user manages their Google Play subscription.
  static const String subscriptionsUrl =
      'https://play.google.com/store/account/subscriptions?package=com.zakerly.ai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
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
            subtitle: 'بياناتك ودرجاتك',
            onTap: () => _showAccount(context, ref),
          ),
          _Tile(
            icon: Icons.workspace_premium_rounded,
            title: 'الاشتراكات والمدفوعات',
            subtitle: 'إدارة الاشتراك والفواتير',
            onTap: () => _open(subscriptionsUrl),
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
            icon: Icons.volume_up_outlined,
            title: 'الأصوات',
            subtitle: 'صوت الإنجاز',
            onTap: () => _showSounds(context),
          ),
          _Tile(
            icon: Icons.language_rounded,
            title: 'اللغة',
            subtitle: 'العربية',
            onTap: () => _showLanguage(context),
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
            child: Text(
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

  void _open(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// A read-only summary of the data stored on this device.
  void _showAccount(BuildContext context, WidgetRef ref) {
    final stats = ref.read(studyStatsProvider);
    final goals = ref.read(goalsProvider);
    final notebooks = ref.read(notebooksProvider);
    final queue = ref.read(reviewQueueProvider);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حسابي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'أيام المذاكرة', value: '${stats.dailyMinutes.length}'),
            _InfoRow(label: 'إجمالي الدقائق', value: '${stats.totalMinutes}'),
            _InfoRow(label: 'السلسلة', value: '${stats.streakDays} يوم'),
            _InfoRow(label: 'الأهداف', value: '${goals.length}'),
            _InfoRow(label: 'الدفاتر', value: '${notebooks.length}'),
            _InfoRow(label: 'كروت المراجعة', value: '${queue.total}'),
            const SizedBox(height: ZakerSpacing.md),
            Text(
              'البيانات دي كلها محفوظة على جهازك، ومفيش حساب سحابي مربوط بيها.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('تمام'),
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
            title: const Text('الأصوات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('صوت الإنجاز'),
                  subtitle: const Text('نقرة قصيرة لما تجاوب أو تفتح هدف'),
                  value: enabled,
                  onChanged: (value) {
                    ref.read(soundsEnabledProvider.notifier).state = value;
                    if (value) {
                      SystemSound.play(SystemSoundType.click);
                    }
                  },
                ),
                Text(
                  'الصوت بيشتغل على إجابات الاختبارات والأهداف.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('تمام'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The language dialog. Only Arabic ships a complete interface.
  void _showLanguage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اللغة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_rounded),
              title: const Text('العربية'),
              subtitle: const Text('اللغة الحالية'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: false,
              leading: Icon(Icons.language_rounded),
              title: Text('English'),
              subtitle: Text('هتتضاف في تحديث جاي'),
            ),
          ],
        ),
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
        title: const Text('الخصوصية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أين تحفظ البيانات؟',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            const Text(
              'أهدافك ومهامك ودفاترك وكلماتك وسجل مذاكرتك بتتحفظ محليًا على '
              'جهازك. مفيش رفع تلقائي لحساب على السحابة.',
            ),
            const SizedBox(height: ZakerSpacing.md),
            _InfoRow(label: 'دقائق مسجلة', value: '${stats.totalMinutes}'),
            _InfoRow(label: 'دفاتر', value: '${notebooks.length}'),
            const SizedBox(height: ZakerSpacing.md),
            Text(
              'أسئلة معلم AI بتبعت للسيرفر وقت ما تستخدم المحادثة بس.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('تمام'),
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
      applicationLegalese: 'نسخة عربية للطلاب — مناهج، اختبارات، تركيز، ومعلم AI.',
      children: const [
        SizedBox(height: ZakerSpacing.md),
        Text(
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
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    final tasks = ref.watch(taskScheduleProvider).forDay();

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
            Text(
              'المنبهات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تذكير المذاكرة'),
              subtitle: const Text('بيظهر جرس في الرئيسية لما يكون عندك مهام'),
              value: enabled,
              onChanged: (value) =>
                  ref.read(notificationsEnabledProvider.notifier).state = value,
            ),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ZakerSpacing.md),
                child: Text('مفيش مهام مجدولة النهارده.'),
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
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: task.dueAt == null
                      ? null
                      : Text(
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
                label: const Text('افتح أهداف اليوم'),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
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
              Text(
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
              child: Text(
                '${e.key}: ${e.value}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
