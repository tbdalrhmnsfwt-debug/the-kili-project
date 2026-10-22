/// The glossary: search the bundled Arabic -> English dictionary
/// (`assets/dictionary/words.json`, 7,046 entries).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/dictionary.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The glossary screen.
class GlossaryScreen extends ConsumerStatefulWidget {
  const GlossaryScreen({super.key});

  @override
  ConsumerState<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends ConsumerState<GlossaryScreen> {
  final TextEditingController _controller = TextEditingController();
  List<WordEntry> _all = const [];
  List<WordEntry> _results = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = ref.read(assetServiceProvider);
    try {
      final dict = await service.loadDictionary();
      if (!mounted) return;
      setState(() {
        _all = dict.entries;
        _results = _all;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _search(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _results = _all;
        return;
      }
      _results = _all
          .where(
            (e) =>
                e.arabic.toLowerCase().contains(q) ||
                e.english.toLowerCase().contains(q),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const TrText('فهرس المصطلحات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.sm,
              ZakerSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _controller,
              onChanged: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'دوّر على كلمة…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Expanded(
            child: _loading
                ? const LoadingBox()
                : _results.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'مفيش نتائج',
                    message: 'جرّب كلمة تانية.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      ZakerSpacing.lg,
                      0,
                      ZakerSpacing.lg,
                      ZakerSpacing.xxl,
                    ),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: ZakerSpacing.lg),
                    itemBuilder: (context, index) {
                      final entry = _results[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            entry.arabic,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 19,
                              height: 1.9,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TrText(
                            entry.english,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
