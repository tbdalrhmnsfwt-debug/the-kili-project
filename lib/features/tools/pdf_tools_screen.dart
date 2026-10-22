/// The PDF tools screen.
///
/// Shipped strings this screen is built from:
///   * `أدوات الـPDF`
///   * `PDF أو صور، أو من مكتبتك`
///   * `PDF وصور وباركود من الموبايل`
///   * `PDF بالحل`
///   * `PDF أو Word — الكتاب كله مرة واحدة`
///   * `أضف صوراً وملفات PDF بالترتيب المطلوب`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/ai.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The PDF / document tools screen.
class PdfToolsScreen extends ConsumerWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheets = ref.watch(aiOutputsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('أدوات الـPDF')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          SectionHeader(title: 'أدواتك', icon: Icons.build_rounded),
          const _ToolGrid(),
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'ورقاتك',
            icon: Icons.description_rounded,
            actionLabel: 'جديد',
            onAction: () => _showAddSheet(context),
          ),
          if (sheets.isEmpty)
            const EmptyState(
              icon: Icons.description_outlined,
              title: 'مفيش ورقات لسه',
              message: 'اعمل ورقة جديدة من صور أو PDF.',
            )
          else
            for (final sheet in sheets)
              _SheetTile(
                sheet: sheet,
                onTap: () => _showSheetDetail(context, ref, sheet),
              ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _AddSheetSheet(),
    );
  }

  void _showSheetDetail(BuildContext context, WidgetRef ref, AiOutput sheet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sheet.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      final outputs = ref.read(aiOutputsProvider);
                      ref.read(aiOutputsProvider.notifier).state = outputs
                          .where((o) => o.id != sheet.id)
                          .toList();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: ZakerSpacing.sm),
              Text(
                sheet.preview.isEmpty ? 'مفيش تفاصيل' : sheet.preview,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: ZakerSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('تم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grid of PDF operations.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid();

  static const _tools = <({String label, IconData icon})>[
    (label: 'PDF من صور', icon: Icons.image_outlined),
    (label: 'PDF بالحل', icon: Icons.task_alt_rounded),
    (label: 'PDF منسق', icon: Icons.format_align_right_rounded),
    (label: 'PDF أسئلة بس', icon: Icons.quiz_outlined),
    (label: 'تضغيم', icon: Icons.compress_rounded),
    (label: 'طباعة', icon: Icons.print_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: ZakerSpacing.sm,
        crossAxisSpacing: ZakerSpacing.sm,
        childAspectRatio: 1.15,
      ),
      itemCount: _tools.length,
      itemBuilder: (context, index) {
        final tool = _tools[index];
        return FeatureTile(
          title: tool.label,
          icon: tool.icon,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${tool.label} — لسه بيتشغّل')),
          ),
        );
      },
    );
  }
}

/// The "add a new sheet" sheet.
class _AddSheetSheet extends StatelessWidget {
  const _AddSheetSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أضف صوراً وملفات PDF بالترتيب المطلوب',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Text(
              'اختار صور أو ملفات، رتّبها، وبعدها تقدر تعمل PDF منهم.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.lg),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.sm,
              children: const [
                _SourceButton(label: 'صور', icon: Icons.photo_library_outlined),
                _SourceButton(
                  label: 'ملفات PDF',
                  icon: Icons.picture_as_pdf_outlined,
                ),
                _SourceButton(
                  label: 'من المكتبة',
                  icon: Icons.folder_open_outlined,
                ),
                _SourceButton(
                  label: 'الكاميرا',
                  icon: Icons.photo_camera_outlined,
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A source picker button.
class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.md,
          vertical: ZakerSpacing.sm,
        ),
      ),
    );
  }
}

/// A single output tile.
class _SheetTile extends StatelessWidget {
  const _SheetTile({required this.sheet, required this.onTap});

  final AiOutput sheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sheet.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
