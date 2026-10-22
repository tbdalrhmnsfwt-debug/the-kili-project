/// The whiteboard: turn a lesson into an animated, narrated explanation.
///
/// Shipped strings this screen is built from:
///   * `اشرح الدرس على السبورة`
///   * `الدرس بيتشرح على سبورة بيضا: قلم بيكتب ويرسم قدامك ورسومات بتتحرك،
///      وصوت بيشرح.`
///   * `بنجهز السبورة…`
///   * `الشرح على السبورة للباقة المدفوعة`
///   * `اشترك وخلي أي درس يترسم ويتشرح على السبورة`
///   * `صوت مصري طبيعي` — the narrator voices the app ships.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The whiteboard feature screen.
class WhiteboardScreen extends ConsumerStatefulWidget {
  const WhiteboardScreen({super.key, this.lessonTitle, this.lessonText});

  /// The lesson the whiteboard will explain.
  final String? lessonTitle;

  /// The lesson body to explain.
  final String? lessonText;

  @override
  ConsumerState<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends ConsumerState<WhiteboardScreen> {
  double _progress = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.lessonTitle ?? ZakerStrings.s_95410; // الدرس على السبورة

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _HeroCard(lessonTitle: title),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_95410,
            icon: Icons.draw_rounded,
          ),
          Text(
            ZakerStrings.s_f398d, // الدرس بيتشرح على سبورة بيضا…
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const _VoicePicker(),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_b055a, // الصوت ده للفيديو والمدرس والسبورة…
            icon: Icons.record_voice_over_rounded,
          ),
          const _VoiceGrid(),
          const SizedBox(height: ZakerSpacing.xl),
          FilledButton.icon(
            onPressed: _progress > 0 && _progress < 1 ? null : _render,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              _progress > 0 && _progress < 1
                  ? ZakerStrings.s_39d66 // بنجهز السبورة…
                  : ZakerStrings.s_ddb1c, // اشرح الدرس على السبورة
            ),
          ),
          if (_progress > 0 && _progress < 1) ...[
            const SizedBox(height: ZakerSpacing.md),
            ProgressBar(value: _progress, height: 6),
          ],
          if (_error != null) ...[
            const SizedBox(height: ZakerSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZakerColors.danger,
              ),
            ),
          ],
          const SizedBox(height: ZakerSpacing.lg),
          const _PaywallNote(),
        ],
      ),
    );
  }

  Future<void> _render() async {
    final ai = ref.read(aiServiceProvider);
    final title = widget.lessonTitle ?? ZakerStrings.s_95410;
    final text = widget.lessonText ?? '';

    setState(() {
      _progress = 0;
      _error = null;
    });

    try {
      final job = await ai.runJob(
        kind: 'whiteboard',
        title: title,
        work: (onProgress) async {
          onProgress(0.25);
          await ai.ask(
            text.isEmpty
                ? ZakerStrings.s_ddb1c // اشرح الدرس على السبورة
                : '${ZakerStrings.s_ddb1c}\n\n$text',
            subject: title,
          );
          onProgress(0.75);
        },
      );
      if (!mounted) return;
      setState(() => _progress = 1);
      if (job.error != null) {
        setState(() => _error = job.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _error = '$e';
      });
    }
  }
}

/// The hero card explaining what the whiteboard does.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.lessonTitle});

  final String lessonTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, ZakerColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.draw_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Text(
            ZakerStrings.s_d3b63, // الدرس مرسوم على السبورة
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            ZakerStrings.s_0e1b4, // درسك يتشرح على السبورة
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The narrator voice the lesson will be spoken in.
class _VoicePicker extends StatelessWidget {
  const _VoicePicker();

  @override
  Widget build(BuildContext context) {
    return const ChipStrip(
      items: ['فهيم', 'نور', 'كريم', 'سلمى'],
      selected: 'فهيم',
      onSelected: _noop,
    );
  }

  static void _noop(String _) {}
}

/// The voice list the user picks from.
class _VoiceGrid extends StatelessWidget {
  const _VoiceGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ZakerStrings.s_1291c, // اختار مدرسك (فهيم أو نور أو كريم أو سلمى)
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        Wrap(
          spacing: ZakerSpacing.sm,
          runSpacing: ZakerSpacing.sm,
          children: [
            for (final voice in const ['فهيم', 'نور', 'كريم', 'سلمى'])
              Chip(
                avatar: const Icon(Icons.record_voice_over_rounded, size: 16),
                label: Text(voice),
              ),
          ],
        ),
      ],
    );
  }
}

/// The note that whiteboard rendering is a paid feature.
class _PaywallNote extends StatelessWidget {
  const _PaywallNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: ZakerColors.accent.withValues(alpha: 0.10),
        borderRadius: ZakerRadius.card,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 20,
            color: ZakerColors.accent,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: Text(
              ZakerStrings.s_3bfdd, // الشرح على السبورة للباقة المدفوعة
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
