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
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/notebook.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import 'notebook_editor_screen.dart';
import '../../widgets/tr_text.dart';

/// The notebooks screen.
class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('ملاحظاتي'),
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
            const TrText(
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
            onAction: () => _showTools(context, ref),
          ),
          _NotebookTypeChips(
            onPick: (variant) => _createFromTemplate(context, ref, variant),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          FeatureTile(
            title: 'تحدث مع النوتة',
            subtitle: 'اسأل نوتتك أي حاجة',
            icon: Icons.forum_rounded,
            onTap: () {
              final subject = notebooks.isEmpty
                  ? null
                  : notebooks.first.subject;
              context.push(
                subject == null
                    ? ZakerRoutes.chat
                    : '${ZakerRoutes.chat}?subject='
                          '${Uri.encodeQueryComponent(subject)}',
              );
            },
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
        title: const TrText('نوتة مادة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'المادة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
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
            child: const TrText('اعمل'),
          ),
        ],
      ),
    );
  }

  /// The body pre-filled into a notebook created from [variant].
  static const Map<String, String> _templates = {
    'ملاحظاتك السريعة': '',
    'ملاحظاتك السريعة اليومية':
        'تاريخ اليوم:\n\nالمهام:\n- \n\nملاحظات:\n',
    'ملاحظات لاصقة':
        'فكرة سريعة:\n\n\nمهم:\n',
    'ملاحظات كورنيل':
        'السؤال أو الفكرة الرئيسية:\n\n\nالملاحظات:\n\n\nالخلاصة:\n',
    'النوتة الذكية':
        'الفكرة:\n\nشرح مبسط:\n\nأسئلة للمراجعة:\n1. \n',
  };

  /// Creates a notebook from one of the note templates and opens it.
  void _createFromTemplate(
    BuildContext context,
    WidgetRef ref,
    String variant,
  ) {
    final id = 'nb-${DateTime.now().millisecondsSinceEpoch}';
    final template = _templates[variant] ?? '';
    final notebooks = ref.read(notebooksProvider);
    ref.read(notebooksProvider.notifier).state = [
      Notebook(
        id: id,
        subject: variant,
        createdAt: DateTime.now(),
        pages: template.isEmpty
            ? null
            : [
                NotebookPage(
                  id: '$id-page-1',
                  title: variant,
                  body: template,
                  createdAt: DateTime.now(),
                ),
              ],
      ),
      ...notebooks,
    ];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotebookEditorScreen(notebookId: id),
      ),
    );
  }

  /// Shows the notebook tools sheet.
  void _showTools(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort_rounded),
              title: const TrText('نظم النوتة'),
              subtitle: const TrText('رتّب النوتات حسب المادة'),
              onTap: () {
                final notebooks = [...ref.read(notebooksProvider)]
                  ..sort((a, b) => a.subject.compareTo(b.subject));
                ref.read(notebooksProvider.notifier).state = notebooks;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: TrText('اتنظمت النوتات ✅')),
                  );
              },
            ),
            for (final entry in _templates.entries)
              ListTile(
                leading: Icon(_templateIcons[entry.key] ?? Icons.note_rounded),
                title: TrText(entry.key),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _createFromTemplate(context, ref, entry.key);
                },
              ),
          ],
        ),
      ),
    );
  }

  static const Map<String, IconData> _templateIcons = {
    'ملاحظاتك السريعة': Icons.bolt_rounded,
    'ملاحظاتك السريعة اليومية': Icons.today_rounded,
    'ملاحظات لاصقة': Icons.sticky_note_2_outlined,
    'ملاحظات كورنيل': Icons.account_tree_outlined,
    'النوتة الذكية': Icons.auto_awesome_rounded,
  };
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
                    TrText(
                      notebook.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ZakerSpacing.xs),
                    TrText(
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
  const _NotebookTypeChips({required this.onPick});

  final ValueChanged<String> onPick;

  static const List<String> _variants = [
    'ملاحظاتك السريعة',
    'ملاحظاتك السريعة اليومية',
    'ملاحظات لاصقة',
    'ملاحظات كورنيل',
    'النوتة الذكية',
  ];

  @override
  Widget build(BuildContext context) {
    return ChipStrip(
      items: _variants,
      selected: null,
      onSelected: onPick,
    );
  }
}
