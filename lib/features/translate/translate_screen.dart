/// The AI translation tool (`ترجمة`).
///
/// Every Arabic literal below is a [ZakerStrings] constant, so the text is
/// byte-identical to what the shipped app renders.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The translation screen.
class TranslateScreen extends ConsumerStatefulWidget {
  const TranslateScreen({super.key});

  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

/// Which way the translation runs.
enum _Direction { engToArabic, arabicToEnglish }

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  final TextEditingController _source = TextEditingController();
  final TextEditingController _target = TextEditingController();
  _Direction _dir = _Direction.engToArabic;
  bool _busy = false;

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Runs the translation through the AI service.
  Future<void> _run(WidgetRef ref) async {
    if (_source.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _target.clear();
    });

    try {
      final ai = ref.read(aiServiceProvider);
      final prompt = _dir == _Direction.engToArabic
          ? 'ترجم النص ده من الإنجليزي للعربي: ${_source.text.trim()}'
          : 'ترجم النص ده من العربي للإنجليزي: ${_source.text.trim()}';
      await ai.ask(prompt);
      if (!mounted) return;
      String reply = '';
      for (final m in ai.history) {
        if (m.role == 'assistant' && m.text.isNotEmpty) reply = m.text;
      }
      setState(() => _target.text = reply);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الترجمة: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ترجمة')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          SectionHeader(
            icon: Icons.translate_rounded,
            title: ZakerStrings.s_79273, // الترجمة بالذكاء الاصطناعي
            actionLabel: ZakerStrings.s_c3465, // ترجم لي
            onAction: () => _run(ref),
          ),
          const SizedBox(height: ZakerSpacing.md),
          TextField(
            controller: _source,
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(
              hintText: ZakerStrings.s_ab238, // اكتب أو الصق النص اللي عايز تترجمه الأول.
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _run(ref),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(
                    () => _dir = _Direction.engToArabic,
                  ),
                  icon: const Icon(Icons.arrow_left_rounded),
                  label: Text(ZakerStrings.s_7f7fb), // ترجم من
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(
                    () => _dir = _Direction.arabicToEnglish,
                  ),
                  icon: const Icon(Icons.arrow_right_rounded),
                  label: Text(ZakerStrings.s_34502), // ترجم إلى
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: ZakerRadius.card,
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.black12,
              ),
            ),
            child: _target.text.isEmpty && !_busy
                ? Text(
                    ZakerStrings.s_b9628, // جاري الترجمة بالذكاء الاصطناعي…
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      _target.text.isEmpty
                          ? ZakerStrings.s_ab238
                          : _target.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          if (_busy)
            const LoadingBox(label: 'جاري الترجمة بالذكاء الاصطناعي…')
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _run(ref),
                    child: Text(ZakerStrings.s_d71e5), // وريني الترجمة
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_target.text.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: _target.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ZakerStrings.s_a7863), // اتنسخت الترجمة ✅
                        ),
                      );
                    },
                    child: Text(ZakerStrings.s_1a4ff), // خبي الترجمة
                  ),
                ),
              ],
            ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_b7323, // ترجمة وشرح المصطلحات
            icon: Icons.spellcheck_rounded,
          ),
          const FeatureTile(
            title: ZakerStrings.s_9fe71, // ترجمة كلمة
            subtitle: 'معنى أي كلمة إنجليزي',
            icon: Icons.abc_rounded,
          ),
        ],
      ),
    );
  }
}
