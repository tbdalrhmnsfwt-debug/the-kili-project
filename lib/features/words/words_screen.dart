/// The vocabulary trainer (`كلمات`).
///
/// Shipped strings this screen is built from:
///   * `كلماتي`
///   * `الكلمات`
///   * `قاموس الكلمات`
///   * `قسم حفظ كلمات الإنجليزي — بيدربك عليها، مش بس بيخزنها.`
///   * `ابدأ بقايمة كلمات`
///   * `إضافة كلمات`
///   * `القايمة فاضية — ضيف كلمات من الزرار اللي فوق.`
///   * `لسه مافيش كلمات — ضيف أول قايمة وابدأ.`
///   * `مافيش كلمات جاهزة للمذاكرة دلوقتي`
///   * `مافيش كلمات مستحقة في القايمة دي دلوقتي — ارجع بكرة`
///   * `ERT` → `اتدرب على حفظ كلماتك`
///   * `لعبة الذاكرة`
///   * `كلمات محتاجة شغل`
///   * `كلمات جديدة في اليوم`
///   * `اللي اتعلمته النهارده`
///   * `اتحفظت {0} كلمة`
///   * `الكلمات الصعبة بس`
///   * `اكتب كلمة جاهز فقط.`
///   * `الكلمة بالإنجليزي`
///   * `معنى أي كلمة إنجليزي`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/words.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The vocabulary screen.
class WordsScreen extends ConsumerWidget {
  const WordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(wordListsProvider);
    final all = lists.expand((l) => l.entries).toList();
    final due = all.where((e) => e.isDue()).toList();

    return Scaffold(
      appBar: AppBar(
        title: const TrText('كلماتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'إضافة كلمات',
            onPressed: () => _addList(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _OverviewCard(total: all.length, due: due.length),
          const SizedBox(height: ZakerSpacing.lg),
          if (lists.isEmpty)
            const EmptyState(
              icon: Icons.library_books_outlined,
              title: 'لسه مافيش كلمات — ضيف أول قايمة وابدأ.',
              message:
                  'قسم حفظ كلمات الإنجليزي — بيدربك عليها، مش بس بيخزنها.',
            )
          else ...[
            const SectionHeader(
              title: 'الكلمات',
              icon: Icons.list_alt_rounded,
            ),
            for (final l in lists) _WordListTile(list: l),
          ],
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'اتدرب على حفظ كلماتك',
            icon: Icons.psychology_rounded,
            actionLabel: 'ابدأ',
            onAction: () => _startReview(context, ref, due),
          ),
          FeatureTile(
            title: 'لعبة الذاكرة',
            subtitle: 'مذاكرة على شكل لعبة — تجاوب صح تتقدم وتكسب.',
            icon: Icons.extension_rounded,
            onTap: () => _startReview(context, ref, due),
          ),
        ],
      ),
    );
  }

  /// Creates a new word list.
  void _addList(BuildContext context, WidgetRef ref) {
    final title = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('ابدأ بقايمة كلمات'),
        content: TextField(
          controller: title,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم القايمة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final name = title.text.trim();
              if (name.isNotEmpty) {
                final lists = ref.read(wordListsProvider);
                ref.read(wordListsProvider.notifier).state = [
                  WordList(
                    id: 'wl-${DateTime.now().millisecondsSinceEpoch}',
                    title: name,
                    createdAt: DateTime.now(),
                  ),
                  ...lists,
                ];
              }
              Navigator.of(context).pop();
            },
            child: const TrText('اعمل'),
          ),
        ],
      ),
    );
  }

  /// Opens the review flow for the due words.
  void _startReview(BuildContext context, WidgetRef ref, List<WordEntry> due) {
    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('مافيش كلمات مستحقة في القايمة دي دلوقتي — ارجع بكرة'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WordReviewScreen()),
    );
  }
}

/// The overview card at the top of the vocabulary screen.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.total, required this.due});

  final int total;
  final int due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, ZakerColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            'قاموس الكلمات',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'قسم حفظ كلمات الإنجليزي — بيدربك عليها، مش بس بيخزنها.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '$total',
                label: 'كلمة',
                icon: Icons.album_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '$due',
                label: 'مستحقة',
                icon: Icons.schedule_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single word list card.
class _WordListTile extends StatelessWidget {
  const _WordListTile({required this.list});

  final WordList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
      child: InkWell(
        borderRadius: ZakerRadius.card,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WordListScreen(listId: list.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TrText(
                      list.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TrText(
                    '${list.entries.length} كلمة',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.md),
              ProgressBar(value: list.progress, height: 6),
              const SizedBox(height: ZakerSpacing.sm),
              Row(
                children: [
                  StatChip(
                    value: '${list.mastered}',
                    label: 'متقنة',
                    icon: Icons.verified_rounded,
                    color: ZakerColors.success,
                  ),
                  const SizedBox(width: ZakerSpacing.sm),
                  StatChip(
                    value: '${list.struggling}',
                    label: 'محتاجة شغل',
                    icon: Icons.priority_high_rounded,
                    color: ZakerColors.danger,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The detail screen for one word list.
class WordListScreen extends ConsumerWidget {
  const WordListScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(wordListsProvider);
    WordList? list;
    for (final l in lists) {
      if (l.id == listId) list = l;
    }

    if (list == null) {
      return Scaffold(
        appBar: AppBar(title: const TrText('قايمة')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'مالقيناش حاجة بالكلام ده',
        ),
      );
    }

    final current = list;

    return Scaffold(
      appBar: AppBar(
        title: TrText(current.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'إضافة كلمات',
            onPressed: () => _addWords(context, ref, current),
          ),
        ],
      ),
      body: current.entries.isEmpty
          ? const EmptyState(
              icon: Icons.playlist_add_rounded,
              title: 'القايمة فاضية — ضيف كلمات من الزرار اللي فوق.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              itemCount: current.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: ZakerSpacing.sm),
              itemBuilder: (context, index) =>
                  _WordTile(entry: current.entries[index]),
            ),
    );
  }

  /// Adds words to a list.
  void _addWords(BuildContext context, WidgetRef ref, WordList list) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('إضافة كلمات'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'اكتب الكلمات، كل كلمة في سطر: english = عربي',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseWordLines(controller.text);
              if (parsed.isNotEmpty) {
                final lists = ref.read(wordListsProvider);
                ref.read(wordListsProvider.notifier).state = [
                  for (final l in lists)
                    if (l.id == list.id)
                      WordList(
                        id: l.id,
                        title: l.title,
                        entries: [...l.entries, ...parsed],
                        createdAt: l.createdAt,
                      )
                    else
                      l,
                ];
              }
              Navigator.of(context).pop();
            },
            child: const TrText('ضيف'),
          ),
        ],
      ),
    );
  }
}

/// Parses pasted vocabulary lines into [WordEntry]s.
///
/// The shipped string spells out the accepted separators:
/// `بيفهم «=» و«-» و«:» والتاب، وكمان سطر إنجليزي وتحته سطر عربي.`
List<WordEntry> parseWordLines(String raw) {
  final entries = <WordEntry>[];
  final lines = raw.split('\n');
  String? pendingEnglish;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final match = RegExp(
      r'^([^=:\-]+?)\s*[=:\-]\s*(.+)$',
    ).firstMatch(trimmed);
    if (match != null) {
      final english = match.group(1)!.trim();
      final arabic = match.group(2)!.trim();
      pendingEnglish = null;
      if (english.isNotEmpty && arabic.isNotEmpty) {
        entries.add(
          WordEntry(
            id: 'w-${DateTime.now().microsecondsSinceEpoch}-${entries.length}',
            english: english,
            arabic: arabic,
            addedAt: DateTime.now(),
          ),
        );
      }
      continue;
    }

    if (pendingEnglish == null) {
      pendingEnglish = trimmed;
    } else {
      entries.add(
        WordEntry(
          id: 'w-${DateTime.now().microsecondsSinceEpoch}-${entries.length}',
          english: pendingEnglish,
          arabic: trimmed,
          addedAt: DateTime.now(),
        ),
      );
      pendingEnglish = null;
    }
  }

  return entries;
}

/// A single vocabulary entry.
class _WordTile extends StatelessWidget {
  const _WordTile({required this.entry});

  final WordEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  entry.english,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TrText(
                  entry.arabic,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          StatChip(
            value: '${entry.box}/${WordEntry.maxBox}',
            label: 'متقنة',
            icon: Icons.layers_rounded,
            color: entry.mastered ? ZakerColors.success : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// The review screen: shows a word and asks for its translation.
class WordReviewScreen extends ConsumerStatefulWidget {
  const WordReviewScreen({super.key});

  @override
  ConsumerState<WordReviewScreen> createState() => _WordReviewScreenState();
}

class _WordReviewScreenState extends ConsumerState<WordReviewScreen> {
  final TextEditingController _answer = TextEditingController();
  int _index = 0;
  bool _revealed = false;
  bool _askingEnglish = true;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(wordListsProvider);
    final due = [
      for (final l in lists)
        ...l.due(),
    ];
    final theme = Theme.of(context);

    if (due.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const TrText('المراجعة')),
        body: const EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'مافيش كلمات جاهزة للمذاكرة دلوقتي',
        ),
      );
    }

    final entry = due[_index % due.length];
    final prompt = _askingEnglish ? entry.english : entry.arabic;
    final expected = _askingEnglish ? entry.arabic : entry.english;

    return Scaffold(
      appBar: AppBar(
        title: TrText('${(_index % due.length) + 1} / ${due.length}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          TrText(
            _askingEnglish
                ? 'إيه معنى الكلمة دي'
                : 'الكلمة بالإنجليزي',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          if (!_revealed)
            TextField(
              controller: _answer,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اكتب كلمة جاهز فقط.',
              ),
              onSubmitted: (_) => _reveal(),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              decoration: BoxDecoration(
                color: ZakerColors.success.withValues(alpha: 0.12),
                borderRadius: ZakerRadius.card,
              ),
              child: Column(
                children: [
                  TrText(
                    expected,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ZakerColors.success,
                    ),
                  ),
                  const SizedBox(height: ZakerSpacing.xs),
                  TrText(
                    'خلاص — دوس صح لو ده المعنى الصح.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZakerSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _record(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const TrText('غلط'),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _record(true),
                    icon: const Icon(Icons.check_rounded),
                    label: const TrText('صح'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: ZakerSpacing.lg),
          if (!_revealed)
            FilledButton(onPressed: _reveal, child: const TrText('وريني')),
          const SizedBox(height: ZakerSpacing.md),
          TextButton(
            onPressed: () => setState(() => _askingEnglish = !_askingEnglish),
            child: TrText(
              _askingEnglish ? 'اسألني عكس' : 'اسألني تاني',
            ),
          ),
        ],
      ),
    );
  }

  void _reveal() {
    setState(() => _revealed = true);
  }

  /// Records the user's answer for the current word.
  void _record(bool wasCorrect) {
    final lists = ref.read(wordListsProvider);
    final due = [for (final l in lists) ...l.due()];
    if (due.isEmpty) return;
    final entry = due[_index % due.length];

    ref.read(wordListsProvider.notifier).state = [
      for (final l in lists)
        WordList(
          id: l.id,
          title: l.title,
          entries: [
            for (final e in l.entries)
              if (e.id == entry.id)
                wasCorrect ? e.correct() : e.wrong()
              else
                e,
          ],
          createdAt: l.createdAt,
        ),
    ];

    setState(() {
      _revealed = false;
      _answer.clear();
      _index++;
    });
  }
}
