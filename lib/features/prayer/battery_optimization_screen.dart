/// Explains and fixes battery optimisation for reliable adhan delivery.
///
/// Android's Doze mode can delay alarms while the phone is idle, and several
/// manufacturers add their own task killers on top.  This screen shows whether
/// the app is already excluded, offers the system exemption dialog, and lists
/// the per-brand settings that commonly need changing.
library;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen>
    with WidgetsBindingObserver {
  bool? _ignoring;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
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
    final ignoring = await AdhanPlatform.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() => _ignoring = ignoring);
  }

  Future<void> _requestExemption() async {
    setState(() => _requesting = true);
    final opened = await AdhanPlatform.requestIgnoreBatteryOptimizations();
    if (!opened) {
      // Some manufacturers do not handle the request intent; fall back to the
      // app's own settings page, where the same switch lives.
      await AdhanPlatform.openAppSettings();
    }
    await _refresh();
    if (mounted) setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ignoring = _ignoring;

    return Scaffold(
      appBar: AppBar(title: const TrText('تحسين البطارية')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            children: [
              _Hero(),
              const SizedBox(height: 16),
              if (ignoring == null)
                _LoadingCard()
              else if (ignoring)
                _ExemptCard()
              else
                _RequestCard(
                  requesting: _requesting,
                  onRequest: _requestExemption,
                ),
              const SizedBox(height: 18),
              const _SectionLabel(title: 'إزاي تعملها بنفسك'),
              const SizedBox(height: 8),
              _StepsCard(),
              const SizedBox(height: 18),
              const _SectionLabel(title: 'لو موبايلك من شركة معينة'),
              const SizedBox(height: 8),
              _OemCard(),
              const SizedBox(height: 18),
              _UnderstoodNote(),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: AdhanPlatform.openAppSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const TrText('افتح إعدادات التطبيق'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
              const SizedBox(height: 10),
              TrText(
                'الصلوات هتشتغل في الغالب حتى من غير التغييرات دي، لكن '
                'النظام ممكن يأخر الإشعار دقايق وهو نايم. الاستثناء بيخلي '
                'الأذان يجي في وقته.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.85,
                  ),
                  fontSize: 10,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedBatteryCharging01,
                size: 23,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 11),
          TrText(
            'خلي الأذان يوصلك في وقته',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          TrText(
            'أندرويد بيحاول يوفّر البطارية بإيقاف التطبيقات اللي مش مفتوحة، '
            'وده ممكن يأخر الأذان. لما تستثني التطبيق من تحسين البطارية، '
            'النظام بيسيب منبهات الأذان تشتغل في معادها.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          TrText(
            'بنتأكد من حالة تحسين البطارية…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExemptCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = ZakerColors.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'التطبيق مستثنى من تحسين البطارية',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  'كويس — النظام مش هيوقف منبهات الأذان وهو نايم.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.requesting, required this.onRequest});

  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = ZakerColors.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_alert_rounded, size: 21, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: TrText(
                  'تحسين البطارية شغال على التطبيق',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          TrText(
            'ده ممكن يأخر الأذان لما الموبايل يكون نايم. اضغط تحت ووافق '
            'على الرسالة اللي هتظهر من النظام.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: requesting ? null : onRequest,
              icon: requesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined, size: 18),
              label: const TrText('استثني التطبيق من تحسين البطارية'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: const Column(
        children: [
          _Step(
            number: '١',
            text: 'افتح إعدادات الموبايل ← التطبيقات ← ذاكرلي.',
          ),
          _Step(number: '٢', text: 'اختار «البطارية» أو «استخدام البطارية».'),
          _Step(
            number: '٣',
            text:
                'غيّر الوضع لـ«غير مقيد» أو فعّل «السماح بالتشغيل في '
                'الخلفية».',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, this.last = false});

  final String number;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: TrText(
                number,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 10.8,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OemCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            'شوية شركات بتحط «قايم التطبيقات» أو مدير طاقة من عندها، وده '
            'بيوقف التطبيق حتى لو استثنيته من تحسين البطارية. لو عندك '
            'موبايل من دول، دور على التطبيق في الإعدادات دي وافتح له '
            'التشغيل التلقائي:',
            style: TextStyle(fontSize: 10.8, height: 1.6),
          ),
          SizedBox(height: 10),
          _OemLine(
            brand: 'شاومي / ريدمي (MIUI)',
            setting:
                'الإعدادات ← التطبيقات ← ذاكرلي ← التشغيل التلقائي، '
                'وبعدين البطارية ← بدون قيود.',
          ),
          _OemLine(
            brand: 'هواوي / هونر',
            setting:
                'إدارة الهاتف ← التطبيقات ← ذاكرلي ← البطارية ← '
                'التشغيل في الخلفية (سيبها شغالة).',
          ),
          _OemLine(
            brand: 'أوبو / ريلمي / ون بلس',
            setting:
                'إعدادات البطارية ← تحسين البطارية ← ذاكرلي ← '
                'اسمح بالتشغيل في الخلفية.',
          ),
          _OemLine(
            brand: 'فيفو / آيكو',
            setting:
                'إدارة البطارية ← استهلاك طاقة عالي في الخلفية ← '
                'اسمح لـذاكرلي.',
          ),
          _OemLine(
            brand: 'سامسونج',
            setting: 'البطارية ← التطبيقات النائمة ← شيل ذاكرلي من القايمة.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _OemLine extends StatelessWidget {
  const _OemLine({
    required this.brand,
    required this.setting,
    this.last = false,
  });

  final String brand;
  final String setting;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  brand,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
                TrText(
                  setting,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.8,
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

class _UnderstoodNote extends StatelessWidget {
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
            'الاستثناء مش بيستهلك بطارية زيادة بشكل ملحوظ — التطبيق مش '
            'بيشتغل في الخلفية، النظام بس بيسيب المنبهات توصل في وقتها.',
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
