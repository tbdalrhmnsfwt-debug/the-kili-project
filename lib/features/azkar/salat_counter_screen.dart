/// The salat-on-the-Prophet counter.
///
/// The three phrases are fixed by the feature brief and live in
/// `core/salat_audio.dart`.  This screen counts taps for the day, offers an
/// optional in-app preview of a user-added recording, and links to the
/// reminder settings.  Licensing information stays in the small About /
/// Licenses entry in settings, never on this screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/router.dart';
import '../../core/salat_audio.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_widgets.dart';

class SalatCounterScreen extends ConsumerStatefulWidget {
  const SalatCounterScreen({super.key, this.initialPhraseId});

  /// The phrase whose notification was tapped, when the screen was opened from
  /// a reminder.
  final String? initialPhraseId;

  @override
  ConsumerState<SalatCounterScreen> createState() => _SalatCounterScreenState();
}

class _SalatCounterScreenState extends ConsumerState<SalatCounterScreen> {
  late String _selectedId;
  String? _previewingId;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    final fromPayload = salatPhraseOrNull(widget.initialPhraseId);
    final selected = ref.read(azkarSettingsProvider).selectedPhrases;
    _selectedId =
        fromPayload?.id ??
        (selected.isEmpty ? kSalatPhrases.first.id : selected.first.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(azkarProgressProvider.notifier).ensureToday();
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    unawaited(AdhanPlatform.stopPreview());
    super.dispose();
  }

  SalatPhrase get _phrase => salatPhraseById(_selectedId);

  void _increment() {
    HapticFeedback.lightImpact();
    ref.read(azkarProgressProvider.notifier).increment(_phrase.counterId);
  }

  Future<void> _preview() async {
    final asset = SalatAudioCatalog.instance.customAssetFor(_phrase.id);
    if (asset == null) return;
    final started = await AdhanPlatform.playPreview('', assetPath: asset);
    if (!mounted) return;
    _previewTimer?.cancel();
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('مش قادرين نشغّل التسجيل ده على الجهاز.'),
        ),
      );
      return;
    }
    setState(() => _previewingId = _phrase.id);
    _previewTimer = Timer(const Duration(seconds: 20), () {
      unawaited(AdhanPlatform.stopPreview());
      if (mounted) setState(() => _previewingId = null);
    });
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    await AdhanPlatform.stopPreview();
    if (mounted) setState(() => _previewingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(azkarSettingsProvider);
    final progress = ref.watch(azkarProgressProvider);
    final phrase = _phrase;
    final count = progress.countFor(phrase.counterId);
    final total = kSalatPhrases.fold<int>(
      0,
      (sum, item) => sum + progress.countFor(item.counterId),
    );
    final sound = settings.soundFor(phrase.id);
    final recording = SalatAudioCatalog.instance.customAssetFor(phrase.id);
    final ring = (count / 100).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('الصلاة على النبي'),
        actions: [
          IconButton(
            tooltip: 'إعدادات التنبيهات',
            onPressed: () => context.push(ZakerRoutes.azkarSettings),
            icon: const Icon(Icons.tune_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          AzkarHero(
            eyebrow: 'ذكر وعدّاد',
            title: 'صلِّ على النبي ﷺ',
            subtitle:
                'اختار الصيغة اللي تحبها، وعدّ براحتك. العدد بيتحفظ لليوم.',
            icon: HugeIcons.strokeRoundedMosque01,
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AzkarPill(
                  label: '${_arabicNumber(total)} مرة النهارده',
                  icon: HugeIcons.strokeRoundedStar,
                  color: ZakerColors.accent,
                ),
                AzkarPill(
                  label: switch (sound) {
                    SalatSoundMode.voice
                        when !SalatAudioCatalog.instance.canSoundNotification(
                          phrase.id,
                        ) =>
                      'تسجيل للمعاينة',
                    SalatSoundMode.voice => 'تنبيه بصوت',
                    SalatSoundMode.chime => 'تنبيه بنغمة',
                    SalatSoundMode.silent => 'تنبيه صامت',
                  },
                  icon: sound == SalatSoundMode.silent
                      ? HugeIcons.strokeRoundedVolumeOff
                      : HugeIcons.strokeRoundedVolumeHigh,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AzkarSectionHeader(
            title: 'اختار الصيغة',
            subtitle: 'نفس الصيغة اللي هتيجي في التذكير',
            icon: HugeIcons.strokeRoundedMusicNote02,
          ),
          const SizedBox(height: 10),
          for (final item in kSalatPhrases) ...[
            _PhraseCard(
              phrase: item,
              selected: item.id == phrase.id,
              sound: settings.soundFor(item.id),
              hasRecording: SalatAudioCatalog.instance.hasRecording(item.id),
              previewing: _previewingId == item.id,
              onTap: () {
                HapticFeedback.selectionClick();
                if (_previewingId != null) unawaited(_stopPreview());
                setState(() => _selectedId = item.id);
              },
              onPreview: _previewingId == item.id
                  ? _stopPreview
                  : item.id == phrase.id
                  ? _preview
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          if (recording == null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'مفيش تسجيل صوتي مرفق للصيغة دي، فالتذكير بيشتغل بالكلام أو النغمة.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            )
          else if (sound == SalatSoundMode.voice &&
              !SalatAudioCatalog.instance.canSoundNotification(phrase.id))
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'التسجيل متاح للمعاينة هنا. الإشعار نفسه بيظهر نص وصامت لحد ما '
                'يتضاف كـ raw resource في أندرويد.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Center(
            child: Semantics(
              button: true,
              label: 'عدّ الصلاة على النبي',
              child: GestureDetector(
                onTap: _increment,
                child: AzkarProgressDial(
                  progress: ring,
                  size: 276,
                  color: ZakerColors.accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _arabicNumber(count),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 56,
                          height: 1,
                          color: ZakerColors.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const TrText(
                        'مرة النهارده',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const TrText(
                        'اضغط للعد',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: count == 0
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(azkarProgressProvider.notifier)
                              .reset(phrase.counterId);
                        },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const TrText('تصفير العدّ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _increment,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const TrText('مرة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AzkarSurface(
            onTap: () => context.push(ZakerRoutes.azkarSettings),
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedNotification01,
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
                      const TrText(
                        'تنبيهات الصلاة على النبي',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      TrText(
                        settings.salatEnabled
                            ? 'شغالة كل ${_arabicNumber(settings.salatIntervalMinutes)} دقيقة — ${settings.salatWindow.label}'
                            : 'متوقفة — فعّلها واختار الفاصل والوقت والصوت.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, size: 21),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.phrase,
    required this.selected,
    required this.sound,
    required this.hasRecording,
    required this.previewing,
    required this.onTap,
    required this.onPreview,
  });

  final SalatPhrase phrase;
  final bool selected;
  final SalatSoundMode sound;
  final bool hasRecording;
  final bool previewing;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    return AzkarSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      borderColor: selected
          ? primary.withValues(alpha: 0.42)
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
      color: selected
          ? primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.055,
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? primary : Colors.transparent,
              border: Border.all(
                color: selected ? primary : muted.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phrase.text,
                  style: TextStyle(
                    fontFamily: ZakerTheme.fontQuran,
                    fontSize: 16,
                    height: 1.7,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      switch (sound) {
                        SalatSoundMode.voice => Icons.volume_up_rounded,
                        SalatSoundMode.chime =>
                          Icons.notifications_active_rounded,
                        SalatSoundMode.silent => Icons.volume_off_rounded,
                      },
                      size: 11,
                      color: muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      switch (sound) {
                        SalatSoundMode.voice => 'صوت',
                        SalatSoundMode.chime => 'نغمة قصيرة',
                        SalatSoundMode.silent => 'صامت',
                      },
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                    if (hasRecording) ...[
                      const SizedBox(width: 7),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: ZakerColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'تسجيل متاح',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ZakerColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onPreview != null)
            IconButton(
              tooltip: previewing ? 'إيقاف المعاينة' : 'معاينة التسجيل',
              onPressed: onPreview,
              icon: Icon(
                previewing
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_outline_rounded,
                color: primary,
                size: 21,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
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
