/// The mutashabihat (similar-words) browser.
///
/// The dataset ships as `assets/quran/mutashabihat.json.gz` with the
/// structure recovered from the APK:
/// ```json
/// {
///   "version": 3, "built": "2026-09-13",
///   "sources": ["qurani.ai", "qul.tarteel.ai"],
///   "meta": {...},
///   "phrases": [ {"t": "…", "o": [["2:23", 15, 17, "both", "A"], …]} ],
///   "pairs":  { "101:6": [["1503", "7:8"]] },
///   "similar":{ "1:1":  [ {"k": "27:30", "s": 80, "c": 50, …} ] },
///   "popular":["2:3", "8:3", …]
/// }
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/dictionary.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Browses the mutashabihat dataset.
class MutashabihatScreen extends ConsumerStatefulWidget {
  const MutashabihatScreen({super.key});

  @override
  ConsumerState<MutashabihatScreen> createState() =>
      _MutashabihatScreenState();
}

class _MutashabihatScreenState extends ConsumerState<MutashabihatScreen> {
  late final Future<MutashabihatData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = ref.read(assetServiceProvider).loadMutashabihat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TrText(ZakerStrings.s_1692c), // متشابهات السورة
      ),
      body: FutureBuilder<MutashabihatData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingBox();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: ZakerStrings.s_0_ef5cc, // مافيش متشابهات في {0}
              message: 'مش قادرين نفتح بيانات المتشابهات دلوقتي.',
              action: FilledButton(
                onPressed: () => setState(() {
                  _future = ref
                      .read(assetServiceProvider)
                      .loadMutashabihat();
                }),
                child: const TrText('جرّب تاني'),
              ),
            );
          }
          return _Content(
            data: snapshot.data!,
            query: _query,
            onQuery: (value) => setState(() => _query = value),
          );
        },
      ),
    );
  }
}

/// The searchable dataset view.
class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.query,
    required this.onQuery,
  });

  final MutashabihatData data;
  final String query;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = query.trim();
    final phrases = q.isEmpty
        ? data.phrases.take(40).toList()
        : data.phrases
              .where(
                (p) =>
                    p.text.contains(q) ||
                    p.refs.any((r) => r.startsWith(q)),
              )
              .take(60)
              .toList();
    final pairs = q.isEmpty
        ? data.pairs.take(30).toList()
        : data.pairs
              .where((p) => p.source.startsWith(q) || p.related.startsWith(q))
              .take(60)
              .toList();

    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        Container(
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
              const Icon(
                Icons.compare_arrows_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const TrText(
                'الآيات اللي بتتلخبط مع بعض — والفرق بينها',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const TrText(
                'ابحث بعبارة أو برقم آية (مثال: 2:3) وهتشوف كل '
                'المواضع المتشابهة.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: ZakerSpacing.md),
              Wrap(
                spacing: ZakerSpacing.sm,
                runSpacing: ZakerSpacing.sm,
                children: [
                  StatChip(
                    value: '${data.phrases.length}',
                    label: 'عبارة',
                    icon: Icons.format_quote_rounded,
                    color: Colors.white,
                  ),
                  StatChip(
                    value: '${data.pairs.length}',
                    label: 'زوج متشابه',
                    icon: Icons.link_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        TextField(
          onChanged: onQuery,
          decoration: const InputDecoration(
            hintText: 'ابحث بعبارة أو رقم آية…',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        SectionHeader(
          title: q.isEmpty ? 'عبارات متكررة' : 'نتايج العبارات (${phrases.length})',
          icon: Icons.format_quote_rounded,
        ),
        if (phrases.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'مفيش عبارة بالبحث ده',
            message: 'جرّب كلمة أقصر أو رقم آية زي 2:3.',
          )
        else
          for (final phrase in phrases) _PhraseCard(phrase: phrase),
        const SizedBox(height: ZakerSpacing.lg),
        SectionHeader(
          title: q.isEmpty ? 'أزواج متشابهة' : 'نتايج الأزواج (${pairs.length})',
          icon: Icons.link_rounded,
        ),
        if (pairs.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'مفيش زوج بالبحث ده',
          )
        else
          for (final pair in pairs) _PairRow(pair: pair),
        const SizedBox(height: ZakerSpacing.lg),
        TrText(
          'المصدر: ${data.sourceFiles.join('، ')} · بناء: ${data.builtAt}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One repeated phrase and every verse it appears in.
class _PhraseCard extends StatelessWidget {
  const _PhraseCard({required this.phrase});

  final MutashabihatPhrase phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = phrase.refs.take(12).toList();
    final extra = phrase.refs.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              phrase.text,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 20,
                height: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              'بتيجي في ${phrase.refs.length} موضع',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Wrap(
              spacing: ZakerSpacing.xs,
              runSpacing: ZakerSpacing.xs,
              children: [
                for (final ref in shown)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TrText(
                      ref,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                if (extra > 0)
                  TrText(
                    '+$extra',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A pair of similar verses.
class _PairRow extends StatelessWidget {
  const _PairRow({required this.pair});

  final MutashabihatPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.md,
          vertical: ZakerSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            _RefChip(ref: pair.source),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: ZakerSpacing.sm),
              child: Icon(
                Icons.compare_arrows_rounded,
                size: 18,
                color: ZakerColors.accent,
              ),
            ),
            _RefChip(ref: pair.related),
            const Spacer(),
            TrText(
              'متشابهة',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefChip extends StatelessWidget {
  const _RefChip({required this.ref});

  final String ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TrText(
        ref,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
