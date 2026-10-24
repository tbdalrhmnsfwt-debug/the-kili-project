/// The adhan voice picker.
///
/// Every bundled recording is listed with its reciter and license, and can be
/// previewed in place before choosing it.  The selected value is persisted
/// immediately, so the settings screen behind the sheet updates right away.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/adhan_voices.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'adhan_providers.dart';
import 'prayer_models.dart';

/// How long a preview plays before it stops on its own, matching the native
/// preview player's timeout.
const Duration _kPreviewLimit = Duration(seconds: 20);

Future<void> showAdhanVoiceSheet(
  BuildContext context, {
  required PrayerName prayer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => _AdhanVoiceSheet(prayer: prayer),
  );
}

class _AdhanVoiceSheet extends ConsumerStatefulWidget {
  const _AdhanVoiceSheet({required this.prayer});

  final PrayerName prayer;

  @override
  ConsumerState<_AdhanVoiceSheet> createState() => _AdhanVoiceSheetState();
}

class _AdhanVoiceSheetState extends ConsumerState<_AdhanVoiceSheet> {
  String? _previewing;
  Timer? _previewTimer;

  @override
  void dispose() {
    _previewTimer?.cancel();
    unawaited(AdhanPlatform.stopPreview());
    super.dispose();
  }

  Future<void> _togglePreview(AdhanVoice voice) async {
    _previewTimer?.cancel();
    if (_previewing == voice.id) {
      await AdhanPlatform.stopPreview();
      if (mounted) setState(() => _previewing = null);
      return;
    }

    setState(() => _previewing = voice.id);
    final playing = await AdhanPlatform.playPreview(voice.resource);
    if (!mounted) return;
    if (!playing) {
      setState(() => _previewing = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: TrText('مش قادر أشغّل الصوت على الجهاز ده.')),
        );
      return;
    }
    _previewTimer = Timer(_kPreviewLimit, () {
      unawaited(AdhanPlatform.stopPreview());
      if (mounted) setState(() => _previewing = null);
    });
  }

  void _select(AdhanVoice voice) {
    ref.read(adhanSettingsProvider.notifier).setVoice(widget.prayer, voice.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(adhanSettingsProvider);
    final selectedId = settings.voiceIdFor(widget.prayer);
    final isFajr = widget.prayer == PrayerName.fajr;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 10, 8),
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
                      icon: HugeIcons.strokeRoundedMusicNote01,
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
                        isFajr ? 'صوت أذان الفجر' : 'صوت الأذان',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 1),
                      TrText(
                        'جرّب الصوت قبل ما تختاره — كله شغال من غير إنترنت.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              itemCount: kAdhanVoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final voice = kAdhanVoices[index];
                return _VoiceCard(
                  voice: voice,
                  selected: voice.id == selectedId,
                  previewing: _previewing == voice.id,
                  fajrHint: isFajr && voice.isFajr,
                  onPreview: () => _togglePreview(voice),
                  onSelect: () => _select(voice),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.offline_bolt_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TrText(
                      'كل الأصوات مرفقة مع التطبيق ومرخّصة للاستخدام.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.previewing,
    required this.fajrHint,
    required this.onPreview,
    required this.onSelect,
  });

  final AdhanVoice voice;
  final bool selected;
  final bool previewing;
  final bool fajrHint;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(11, 11, 13, 11),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.07,
                  )
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.42)
                  : theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            children: [
              _PreviewButton(
                previewing: previewing,
                selected: selected,
                onTap: onPreview,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: TrText(
                            voice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: accent,
                            ),
                          ),
                        ),
                        if (voice.isFajr) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: fajrHint ? 'مناسب للفجر' : 'أذان فجر',
                            color: theme.colorScheme.primary,
                          ),
                        ],
                        if (voice.isTakbeer) ...[
                          const SizedBox(width: 6),
                          _Badge(
                            label: 'قصير',
                            color: theme.colorScheme.tertiary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      '${voice.reciter} · ${voice.license}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.previewing,
    required this.selected,
    required this.onTap,
  });

  final bool previewing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: previewing ? 'إيقاف المعاينة' : 'معاينة الصوت',
      child: Material(
        color: previewing
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: HugeIcon(
              icon: previewing
                  ? HugeIcons.strokeRoundedPause
                  : HugeIcons.strokeRoundedPlay,
              size: 20,
              color: previewing
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TrText(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 8.5,
        ),
      ),
    );
  }
}
