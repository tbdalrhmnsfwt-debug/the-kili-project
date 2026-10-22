/// The notebook editor: a page of a notebook.
///
/// Shipped strings this screen is built from:
///   * `اكتب ملاحظاتك هنا… أو دوس المايك واتكلم.`
///   * `📊 جودة نوتتك`
///   * `جودة النوتة`
///   * `احفظ كصفحة في النوتة`
///   * `اتحفظ كصفحة في نوتتك ✅`
///   * `حذف النوتة`
///   * `حذف النوتة؟`
///   * `النوتة اتحذفت`
///   * `نوتتك طويلة — بنسأل في أولها بس. لو سؤالك عن آخرها، انقله في نوتة لوحده.`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/notebook.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The notebook editor screen.
class NotebookEditorScreen extends ConsumerStatefulWidget {
  const NotebookEditorScreen({super.key, required this.notebookId});

  /// The id of the notebook being edited.
  final String notebookId;

  @override
  ConsumerState<NotebookEditorScreen> createState() => _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends ConsumerState<NotebookEditorScreen> {
  final TextEditingController _body = TextEditingController();
  final TextEditingController _title = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _body.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notebooks = ref.watch(notebooksProvider);
    final notebook = _find(notebooks);
    final theme = Theme.of(context);

    if (notebook == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('نوتة')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'مش لاقي الإجابة في ملاحظاتك.',
        ),
      );
    }

    if (!_loaded) {
      _loaded = true;
      _body.text = notebook.pages.isEmpty ? '' : notebook.pages.last.body;
      _title.text = notebook.pages.isEmpty ? '' : notebook.pages.last.title;
    }

    final quality = _quality(_body.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(notebook.subject),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'حذف النوتة',
            onPressed: () => _delete(context, ref, notebook),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              hintText: 'عنوان الصفحة',
              border: InputBorder.none,
              filled: false,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(),
          TextField(
            controller: _body,
            maxLines: null,
            minLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'اكتب ملاحظاتك هنا… أو دوس المايك واتكلم.',
              border: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          _QualityCard(quality: quality),
          const SizedBox(height: ZakerSpacing.lg),
          FilledButton.icon(
            onPressed: () => _save(context, ref, notebook),
            icon: const Icon(Icons.save_rounded),
            label: const Text('احفظ كصفحة في النوتة'),
          ),
        ],
      ),
    );
  }

  /// Finds the notebook this screen edits.
  Notebook? _find(List<Notebook> notebooks) {
    for (final n in notebooks) {
      if (n.id == widget.notebookId) return n;
    }
    return null;
  }

  /// The crude quality score of the current body.
  int _quality(String body) {
    final words =
        body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words * 2).clamp(0, 100);
  }

  /// Appends the current text as a new page.
  void _save(BuildContext context, WidgetRef ref, Notebook notebook) {
    final body = _body.text.trim();
    if (body.isEmpty) return;

    final page = NotebookPage(
      id: 'page-${DateTime.now().millisecondsSinceEpoch}',
      body: body,
      title: _title.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final notebooks = ref.read(notebooksProvider);
    ref.read(notebooksProvider.notifier).state = [
      for (final n in notebooks)
        if (n.id == notebook.id)
          Notebook(
            id: n.id,
            subject: n.subject,
            pages: [...n.pages, page],
            createdAt: n.createdAt,
          )
        else
          n,
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اتحفظ كصفحة في نوتتك ✅')),
    );
  }

  /// Deletes the whole notebook.
  void _delete(BuildContext context, WidgetRef ref, Notebook notebook) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف النوتة؟'),
        content: Text('هتتشال «${notebook.subject}» وكل صفحاتها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final notebooks = ref.read(notebooksProvider);
              ref.read(notebooksProvider.notifier).state = [
                for (final n in notebooks)
                  if (n.id != notebook.id) n,
              ];
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('النوتة اتحذفت')),
              );
            },
            child: const Text('احذف'),
          ),
        ],
      ),
    );
  }
}

/// The "note quality" card.
class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.quality});

  final int quality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
              Icon(Icons.insights_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: ZakerSpacing.sm),
              Text(
                '📊 جودة نوتتك',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(value: quality / 100, height: 8),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            'جودة النوتة: $quality%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
