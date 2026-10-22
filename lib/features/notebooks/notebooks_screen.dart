/// The notes / notebooks screen.
///
/// Shipped strings this screen is built from:
///   * `دفتر ملاحظاتك جوه التطبيق — تكتب فيه وتنظم وترجعله وقت المراجعة.`
///   * `رياضيات، عربي، علوم… كل مادة نوتة مستقلة`
///   * `نوتة مادة جديدة`
///   * `نظم النوتة`
///   * `أدوات النوتة`
///   * `📊 جودة نوتتك`
///   * `ملاحظاتك السريعة`
///   * `ملاحظاتك السريعة اليومية`
///   * `ملاحظات لاصقة`
///   * `ملاحظات كورنيل`
///   * `النوتة الذكية`
///   * `ابدأ اكتب ملاحظاتك`
///   * `اكتب ملاحظاتك هنا… أو دوس المايك واتكلم.`
///   * `تحدث مع النوتة`
///   * `احفظ كصفحة في النوتة`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/notebook.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import 'notebook_editor_screen.dart';

/// The notebooks screen.
class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملاحظاتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'نوتة مادة جديدة',
            onPressed: () => _createNotebook(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          if (notebooks.isEmpty)
            const EmptyState(
              icon: Icons.edit_note_rounded,
              title: 'ابدأ اكتب ملاحظاتك',
              message:
                  'دفتر ملاحظاتك جوه التطبيق — تكتب فيه وتنظم وترجعله وقت المراجعة.',
            )
          else ...[
            const Text(
              'رياضيات، عربي، علوم… كل مادة نوتة مستقلة',
            ),
            const SizedBox(height: ZakerSpacing.lg),
            for (final n in notebooks)
              _NotebookTile(notebook: n),
          ],
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'أدوات النوتة',
            icon: Icons.auto_awesome_rounded,
            actionLabel: 'المزيد',
            onAction: () => _showTools(context),
          ),
          const _NotebookTypeChips(),
          const SizedBox(height: ZakerSpacing.lg),
          const FeatureTile(
            title: 'تحدث مع النوتة',
            subtitle: 'اسأل نوتتك أي حاجة',
            icon: Icons.forum_rounded,
          ),
        ],
      ),
    );
  }

  /// Creates a new notebook for a subject.
  void _createNotebook(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نوتة مادة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'المادة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final subject = controller.text.trim();
              if (subject.isNotEmpty) {
                final notebooks = ref.read(notebooksProvider);
                ref.read(notebooksProvider.notifier).state = [
                  Notebook(
                    id: 'nb-${DateTime.now().millisecondsSinceEpoch}',
                    subject: subject,
                    createdAt: DateTime.now(),
                  ),
                  ...notebooks,
                ];
              }
              Navigator.of(context).pop();
            },
            child: const Text('اعمل'),
          ),
        ],
      ),
    );
  }

  /// Shows the notebook tools sheet.
  void _showTools(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tool in const [
              ('نظم النوتة', Icons.sort_rounded),
              ('ملاحظاتك السريعة', Icons.bolt_rounded),
              ('ملاحظات لاصقة', Icons.sticky_note_2_outlined),
              ('ملاحظات كورنيل', Icons.account_tree_outlined),
              ('النوتة الذكية', Icons.auto_awesome_rounded),
            ])
              ListTile(
                leading: Icon(tool.$2),
                title: Text(tool.$1),
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single notebook card.
class _NotebookTile extends StatelessWidget {
  const _NotebookTile({required this.notebook});

  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
      child: InkWell(
        borderRadius: ZakerRadius.card,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NotebookEditorScreen(notebookId: notebook.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Row(
            children: [
              Icon(Icons.note_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notebook.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ZakerSpacing.xs),
                    Text(
                      '${notebook.wordCount} كلمة · ${notebook.pages.length} صفحة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatChip(
                value: '${notebook.pages.length}',
                label: 'صفحة',
                icon: Icons.description_outlined,
                color: ZakerColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The set of notebook variants offered on this screen.
class _NotebookTypeChips extends StatelessWidget {
  const _NotebookTypeChips();

  static const List<String> _variants = [
    'ملاحظاتك السريعة',
    'ملاحظاتك السريعة اليومية',
    'ملاحظات لاصقة',
    'ملاحظات كورنيل',
    'النوتة الذكية',
  ];

  @override
  Widget build(BuildContext context) {
    return ChipStrip(items: _variants, selected: null, onSelected: (_) {});
  }
}
