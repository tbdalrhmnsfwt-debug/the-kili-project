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
import '../../models/ai.dart' show AiBackend;
import '../../models/dictionary.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

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
  final FocusNode _sourceFocus = FocusNode();
  _Direction _dir = _Direction.engToArabic;
  bool _busy = false;

  /// Why there is no translation, when the service could not produce one.
  String? _notice;

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    _sourceFocus.dispose();
    super.dispose();
  }

  /// Runs the translation through the AI service.
  Future<void> _run(WidgetRef ref) async {
    if (_source.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _notice = null;
      _target.clear();
    });

    try {
      final ai = ref.read(aiServiceProvider);
      final prompt = _dir == _Direction.engToArabic
          ? 'ترجم النص ده من الإنجليزي للعربي: ${_source.text.trim()}'
          : 'ترجم النص ده من العربي للإنجليزي: ${_source.text.trim()}';
      final answer = await ai.askDetailed(prompt);
      if (!mounted) return;
      // The canned reply is the app talking about its own tools, not a
      // translation of the student's text — showing it as one was the bug.
      if (answer.backend == AiBackend.canned) {
        setState(() => _notice = 'الخدمة مش متاحة دلوقتي');
        return;
      }
      setState(() => _target.text = answer.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TrText('فشل الترجمة: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const TrText('ترجمة')),
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
            focusNode: _sourceFocus,
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
                  label: TrText(ZakerStrings.s_7f7fb), // ترجم من
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(
                    () => _dir = _Direction.arabicToEnglish,
                  ),
                  icon: const Icon(Icons.arrow_right_rounded),
                  label: TrText(ZakerStrings.s_34502), // ترجم إلى
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
                ? TrText(
                    _notice ??
                        ZakerStrings.s_ab238, // اكتب أو الصق النص اللي عايز تترجمه الأول.
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _notice == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
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
                    child: TrText(ZakerStrings.s_d71e5), // وريني الترجمة
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
                          content: TrText(ZakerStrings.s_a7863), // اتنسخت الترجمة ✅
                        ),
                      );
                    },
                    child: const TrText('انسخ الترجمة'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_b7323, // ترجمة وشرح المصطلحات
            icon: Icons.spellcheck_rounded,
          ),
          FeatureTile(
            title: ZakerStrings.s_9fe71, // ترجمة كلمة
            subtitle: 'دور على معنى أي كلمة في القاموس — من غير نت',
            icon: Icons.abc_rounded,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: ZakerRadius.sheet,
              ),
              builder: (_) => const _WordLookupSheet(),
            ),
          ),
        ],
      ),
    );
  }
}

/// An offline dictionary lookup over the bundled word list.
class _WordLookupSheet extends ConsumerStatefulWidget {
  const _WordLookupSheet();

  @override
  ConsumerState<_WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends ConsumerState<_WordLookupSheet> {
  final TextEditingController _query = TextEditingController();
  late final Future<DictionaryEntry> _dictionary;

  @override
  void initState() {
    super.initState();
    _dictionary = ref.read(assetServiceProvider).loadDictionary();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Folds Arabic diacritics so a plain query still matches a vocalised word.
  static String _fold(String text) =>
      text.replaceAll(RegExp(r'[ً-ْٰـ]'), '').toLowerCase();

  List<WordEntry> _matches(DictionaryEntry dictionary) {
    final q = _fold(_query.text.trim());
    if (q.isEmpty) return dictionary.entries.take(30).toList();
    final out = <WordEntry>[];
    for (final entry in dictionary.entries) {
      if (_fold(entry.arabic).contains(q) ||
          entry.english.toLowerCase().contains(q)) {
        out.add(entry);
        if (out.length >= 50) break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                0,
                ZakerSpacing.lg,
                ZakerSpacing.md,
              ),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'اكتب كلمة بالعربي أو بالإنجليزي',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<DictionaryEntry>(
                future: _dictionary,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingBox();
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'القاموس مش متاح',
                      message: 'جرّب تفتح الشاشة تاني.',
                    );
                  }
                  final matches = _matches(snapshot.data!);
                  if (matches.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'مفيش نتيجة',
                      message: 'جرّب كلمة أقصر أو بالعربي.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      ZakerSpacing.lg,
                      0,
                      ZakerSpacing.lg,
                      ZakerSpacing.lg,
                    ),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = matches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: TrText(
                          entry.arabic,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: TrText(entry.english),
                        trailing: IconButton(
                          tooltip: 'انسخ',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: '${entry.arabic} — ${entry.english}',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: TrText('اتنسخت الكلمة ✅'),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
