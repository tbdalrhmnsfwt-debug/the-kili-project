/// The whiteboard: turn a lesson into an animated, narrated explanation.
///
/// Shipped strings this screen is built from:
///   * `اشرح الدرس على السبورة`
///   * `الدرس بيتشرح على سبورة بيضا: قلم بيكتب ويرسم قدامك ورسومات بتتحرك،
///      وصوت بيشرح.`
///   * `بنجهز السبورة…`
///   * `صوت مصري طبيعي` — the narrator voices the app ships.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

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

  /// The narrator picked for the render.
  String _voice = 'فهيم';

  /// The explanation written on the board once a render completes.
  String? _script;

  /// The lesson text the user pastes when the screen is opened standalone.
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.lessonText ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.lessonTitle ?? ZakerStrings.s_95410; // الدرس على السبورة

    return Scaffold(
      appBar: AppBar(title: TrText(title)),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _HeroCard(lessonTitle: title),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_95410,
            icon: Icons.draw_rounded,
          ),
          TrText(
            ZakerStrings.s_f398d, // الدرس بيتشرح على سبورة بيضا…
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'نص الدرس (اختياري)',
              hintText: 'الصق فقرة من درسك وهنشرحها على السبورة.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          _VoicePicker(
            selected: _voice,
            onSelected: (voice) => setState(() => _voice = voice),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_b055a, // الصوت ده للفيديو والمدرس والسبورة…
            icon: Icons.record_voice_over_rounded,
          ),
          _VoiceGrid(
            selected: _voice,
            onSelected: (voice) => setState(() => _voice = voice),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          FilledButton.icon(
            onPressed: _progress > 0 && _progress < 1 ? null : _render,
            icon: const Icon(Icons.play_arrow_rounded),
            label: TrText(
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
            TrText(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZakerColors.danger,
              ),
            ),
          ],
          if (_script != null) ...[
            const SizedBox(height: ZakerSpacing.xl),
            _BoardResult(
              title: title,
              voice: _voice,
              script: _script!,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _render() async {
    final ai = ref.read(aiServiceProvider);
    final title = widget.lessonTitle ?? ZakerStrings.s_95410;
    final text = _textController.text.trim().isEmpty
        ? (widget.lessonText ?? '').trim()
        : _textController.text.trim();
    final prompt = text.isEmpty
        ? '${ZakerStrings.s_ddb1c}\n\nموضوع الدرس: $title'
              '\n\nالصوت: $_voice'
        : '${ZakerStrings.s_ddb1c}\n\nموضوع الدرس: $title\n\n$text'
              '\n\nالصوت: $_voice';

    setState(() {
      _progress = 0;
      _error = null;
      _script = null;
    });

    try {
      late String explanation;
      final job = await ai.runJob(
        kind: 'whiteboard',
        title: title,
        work: (onProgress) async {
          onProgress(0.25);
          explanation = await ai.ask(prompt, subject: title);
          onProgress(0.75);
        },
      );
      if (!mounted) return;
      setState(() {
        _progress = 1;
        if (job.error == null) _script = explanation;
      });
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
          colors: ZakerColors.navyGradient,
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
          TrText(
            ZakerStrings.s_d3b63, // الدرس مرسوم على السبورة
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
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

/// The explanation once the render finishes, presented on a white board.
class _BoardResult extends StatelessWidget {
  const _BoardResult({
    required this.title,
    required this.voice,
    required this.script,
  });

  final String title;
  final String voice;
  final String script;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: script));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: TrText('اتنسخ الشرح ✅')));
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0F172A);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: ZakerColors.primary, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: ZakerColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: ZakerSpacing.md,
              vertical: ZakerSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.draw_rounded, color: Colors.white, size: 18),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: TrText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TrText(
                    'صوت $voice',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'انسخ الشرح',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copy(context),
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            child: TrText(
              script,
              style: const TextStyle(
                color: ink,
                fontSize: 14.5,
                height: 1.95,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The narrator voice the lesson will be spoken in.
class _VoicePicker extends StatelessWidget {
  const _VoicePicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChipStrip(
      items: const ['فهيم', 'نور', 'كريم', 'سلمى'],
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// The voice list the user picks from.
class _VoiceGrid extends StatelessWidget {
  const _VoiceGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrText(
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
              ChoiceChip(
                avatar: Icon(
                  Icons.record_voice_over_rounded,
                  size: 16,
                  color: voice == selected ? theme.colorScheme.primary : null,
                ),
                label: TrText(voice),
                selected: voice == selected,
                onSelected: (_) => onSelected(voice),
              ),
          ],
        ),
      ],
    );
  }
}
