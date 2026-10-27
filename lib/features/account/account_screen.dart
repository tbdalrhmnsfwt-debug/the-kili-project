/// The account screen: profile, sign-in, and the live-sync switch.
///
/// Accounts use Firebase Authentication through [AuthService]; when no Web API
/// key is available the screen stays in guest mode, which is enough for every
/// offline feature. The profile is persisted locally and the Firebase token is
/// deliberately never written to disk.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_service.dart';
import '../../core/guest_profile.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../batches/claim_batches_prompt.dart';

/// The account screen.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final stats = ref.watch(studyStatsProvider);
    final liveEnabled = ref.watch(liveEnabledProvider);
    final settings = ref.watch(appSettingsProvider);
    final apiKey = _apiKeyFrom(settings.valueOrNull);
    final guest = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(title: const TrText('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _ProfileCard(user: user),
          const SizedBox(height: ZakerSpacing.lg),
          if (guest) ...[
            const SectionHeader(
              title: 'تسجيل الدخول',
              icon: Icons.login_rounded,
            ),
            if (apiKey.isEmpty)
              const _Hint(
                'تسجيل الدخول بيحتاج مفتاح Firebase من إعدادات السيرفر. '
                'كل حاجة في التطبيق شغالة دلوقتي بحساب الضيف.',
              )
            else ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الإيميل',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              TextField(
                controller: _password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'كلمة السر',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _submit(create: false),
                      child: TrText(_busy ? '…' : 'دخول'),
                    ),
                  ),
                  const SizedBox(width: ZakerSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _submit(create: true),
                      child: const TrText('حساب جديد'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                'بتوافق على إن الإيميل بيتحفظ على جهازك عشان تسجّل دخول تاني.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ] else ...[
            const SectionHeader(
              title: 'بيانات الحساب',
              icon: Icons.badge_outlined,
            ),
            _InfoRow(
                label: 'الإيميل', value: user.email.isEmpty ? '—' : user.email),
            _InfoRow(label: 'المعرّف', value: user.uid),
            const SizedBox(height: ZakerSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _rename,
                    icon: const Icon(Icons.edit_outlined),
                    label: const TrText('تغيير الاسم'),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const TrText('تسجيل خروج'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: 'المزامنة المباشرة',
            icon: Icons.cloud_sync_outlined,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const TrText('المتصدرين والتحديات المشتركة'),
            subtitle: TrText(
              liveEnabled
                  ? 'التطبيق بيقرا ويكتب المتصدرين والتحديات على السيرفر.'
                  : 'متوقفة — النقاط والمتصدرين بيتحسبوا على جهازك بس.',
            ),
            value: liveEnabled,
            onChanged: (value) {
              ref.read(liveEnabledProvider.notifier).state = value;
              if (value) ref.invalidate(liveLeaderboardProvider);
            },
          ),
          if (liveEnabled && guest)
            const _Hint(
              'المزامنة من غير تسجيل دخول ممكن ترفضها قواعد السيرفر. '
              'سجّل دخول لو عايز نقاطك تظهر لغيرك.',
            ),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(title: 'إحصائياتك', icon: Icons.insights_rounded),
          _InfoRow(
              label: 'أيام المذاكرة', value: '${stats.dailyMinutes.length}'),
          _InfoRow(label: 'إجمالي الدقائق', value: '${stats.totalMinutes}'),
          _InfoRow(label: 'السلسلة', value: '${stats.streakDays} يوم'),
        ],
      ),
    );
  }

  Future<void> _submit({required bool create}) async {
    final settings = ref.read(appSettingsProvider).valueOrNull;
    final apiKey = _apiKeyFrom(settings);
    if (apiKey.isEmpty) {
      _snack('مفتاح Firebase مش متاح — كمّل كضيف.');
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) {
      _snack('اكتب إيميل وكلمة سر ٦ حروف على الأقل.');
      return;
    }
    final guestUid = ref.read(guestProfileStoreProvider).loadOrCreate().uid;
    setState(() => _busy = true);
    AuthUser? signedIn;
    try {
      final service = ref.read(authServiceProvider);
      final user = create
          ? await service.signUp(
              email: email,
              password: password,
              apiKey: apiKey,
            )
          : await service.signInWithPassword(
              email: email,
              password: password,
              apiKey: apiKey,
            );
      signedIn = user;
      ref.read(authUserProvider.notifier).state = user;
      ref.invalidate(liveLeaderboardProvider);
      if (!mounted) return;
      _snack(create ? 'الحساب اتعمل بنجاح.' : 'أهلًا بيك تاني 👋');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('حصلت مشكلة في تسجيل الدخول.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (signedIn == null || !mounted) return;
    await offerBatchClaimIfNeeded(
      context: context,
      ref: ref,
      guestUid: guestUid,
      accountUid: signedIn.uid,
    );
  }

  Future<void> _rename() async {
    final user = ref.read(authUserProvider);
    final controller = TextEditingController(text: user?.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('تغيير الاسم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'الاسم اللي يظهر في المتصدرين'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const TrText('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(authServiceProvider).updateDisplayName(name);
      ref.read(authUserProvider.notifier).state = updated;
      if (updated.isAnonymous) {
        ref
            .read(guestProfileStoreProvider)
            .save(GuestProfile(uid: updated.uid, displayName: name));
      }
      if (mounted) _snack('الاسم اتحدّث.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signOut();
      final profile = ref.read(guestProfileStoreProvider).loadOrCreate();
      final guest = ref.read(authServiceProvider).startGuest(
            uid: profile.uid,
            displayName: profile.displayName,
          );
      ref.read(authUserProvider.notifier).state = guest;
      ref.invalidate(liveLeaderboardProvider);
      if (mounted) _snack('خرجت من الحساب ورجعت لمساحة الضيف.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: TrText(message)));
  }

  /// The Firebase Web API key, when the remote settings document provides one.
  static String _apiKeyFrom(Map<String, dynamic>? settings) {
    if (settings == null) return '';
    for (final key in const [
      'firebaseApiKey',
      'firebase_api_key',
      'firebaseKey',
      'firebase.key',
    ]) {
      final value = settings[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}

/// The gradient profile header.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user?.displayName ?? 'ضيف';
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: ZakerColors.navyGradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: TrText(
              name.characters.first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TrText(
                  (user?.isAnonymous ?? true) ? 'حساب ضيف' : 'حساب مسجّل',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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

/// A single label/value row.
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
          Flexible(
            child: TrText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small explanatory note.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: ZakerRadius.card,
      ),
      child: TrText(text, style: theme.textTheme.bodySmall),
    );
  }
}
