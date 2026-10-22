/// Settings and the account section.
///
/// The original app's settings group its entries under headings recovered
/// from the shipped strings — e.g. "2. أين تحفظ البيانات؟",
/// "4. الاشتراكات والمدفوعات" — and links out to
/// `play.google.com/store/account/subscriptions?package=com.zakerly.ai`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
            onTap: () {},
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
            onTap: () {},
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(title: 'التطبيق', icon: Icons.settings_rounded),
          _Tile(
            icon: Icons.notifications_outlined,
            title: 'المنبهات',
            subtitle: 'تذكير المذاكرة',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.volume_up_outlined,
            title: 'الأصوات',
            subtitle: 'صوت الإنجاز',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.language_rounded,
            title: 'اللغة',
            subtitle: 'العربية',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.shield_outlined,
            title: 'الخصوصية',
            subtitle: 'أين تحفظ البيانات؟',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.info_outline_rounded,
            title: 'عن ذاكرلي',
            subtitle: 'عن التطبيق',
            onTap: () {},
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
