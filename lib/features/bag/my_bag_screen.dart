import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization.dart';
import '../../core/my_bag/my_bag_models.dart';
import '../../core/router.dart';
import '../../core/study_library.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/my_bag_providers.dart';
import '../../providers/pdf_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../home/shell_screen.dart';
import 'bag_visuals.dart';
import 'widgets/bag_folder_card.dart';

/// The second tab: «شنطتي» — every subject's pockets in one place.
class MyBagScreen extends ConsumerStatefulWidget {
  const MyBagScreen({super.key});

  @override
  ConsumerState<MyBagScreen> createState() => _MyBagScreenState();
}

/// One titled run of folder cards.
class _BagSection {
  const _BagSection(
      {required this.id, required this.title, required this.folders});

  final String id;
  final String title;
  final List<MyBagFolder> folders;
}

class _MyBagScreenState extends ConsumerState<MyBagScreen> {
  /// `null` = the selected grade, `'*'` = every grade, else a grade id.
  String? _gradeFilter;
  bool _searching = false;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bag = ref.watch(myBagControllerProvider);
    final progress = ref.watch(bagSubjectProgressProvider);
    final currentGrade = ref.watch(selectedGradeProvider);
    final query = _search.text.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final folders = bag.index.folders;
    final sections = searching
        ? _searchSections(folders, query)
        : _gradeSections(folders, currentGrade);
    final empty = folders.isEmpty && !searching;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1000
        ? 4
        : width >= 700
            ? 3
            : 2;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardExtent = 170 + (scale - 1) * 75;

    return Scaffold(
      key: const Key('my-bag-screen'),
      appBar: AppBar(
        // Pushed on top of a shell (a /bag deep link from a card), the screen
        // needs a way back; inside the shell's own tab, the menu is the way out.
        leading: Navigator.of(context).canPop()
            ? const BackButton()
            : shellMenuLeading(context),
        title: const TrText('شنطتي'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.lg,
              ZakerSpacing.lg,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _BagHero(totals: bag.totals, onOpenLibrary: _openLibrary),
                const SizedBox(height: ZakerSpacing.md),
                _filterRow(context, currentGrade),
                if (_searching) ...[
                  const SizedBox(height: ZakerSpacing.sm),
                  TextField(
                    key: const Key('my-bag-search-field'),
                    controller: _search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('بحث في شنطتي'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ]),
            ),
          ),
          if (empty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: EmptyState(
                  key: const Key('my-bag-empty'),
                  icon: Icons.backpack_outlined,
                  title: 'لسه مفيش مواد في الشنطة',
                  message: 'المواد بتتضاف أوتوماتيك من الصف اللي مختاره.',
                ),
              ),
            ),
          for (final section in sections) ...[
            SliverToBoxAdapter(
              child: Padding(
                key: Key('my-bag-section-${section.id}'),
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.lg,
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                ),
                child: SectionHeader(
                  title: section.title,
                  icon: Icons.folder_outlined,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZakerSpacing.lg,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: ZakerSpacing.md,
                  crossAxisSpacing: ZakerSpacing.md,
                  mainAxisExtent: cardExtent,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final folder = section.folders[index];
                  return BagFolderCard(
                    key: Key('bag-folder-card-${folder.id}'),
                    folder: folder,
                    totals: bag.totalsFor(folder.id),
                    progress: folder.custom
                        ? null
                        : progress[bagProgressKey(
                            folder.gradeId,
                            folder.subjectKey,
                          )],
                    onOpen: () => _openFolder(folder),
                    onRename: () => _renameFolder(folder),
                    onColor: () => _pickColor(folder),
                    onDelete: () => _deleteFolder(folder),
                  );
                }, childCount: section.folders.length),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.lg,
              ZakerSpacing.lg,
              ZakerSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: _AddFolderCard(onTap: _addCustomFolder),
            ),
          ),
        ],
      ),
    );
  }

  List<_BagSection> _searchSections(List<MyBagFolder> folders, String query) {
    final matches = [
      for (final folder in folders)
        if (folder.name.toLowerCase().contains(query)) folder,
    ];
    if (matches.isEmpty) return const [];
    return [
      _BagSection(id: 'search', title: 'نتائج البحث', folders: matches),
    ];
  }

  List<_BagSection> _gradeSections(List<MyBagFolder> folders, String current) {
    final sections = <_BagSection>[];
    final custom = [
      for (final folder in folders)
        if (folder.custom) folder,
    ];
    if (custom.isNotEmpty) {
      sections.add(
        _BagSection(id: 'custom', title: 'مجلداتي', folders: custom),
      );
    }

    List<String> gradeIds;
    if (_gradeFilter == '*') {
      gradeIds = [
        for (final id in kGradeLabels.keys)
          if (folders.any((folder) => !folder.custom && folder.gradeId == id))
            id,
      ];
      for (final folder in folders) {
        if (folder.custom || folder.gradeId.isEmpty) continue;
        if (kGradeLabels.containsKey(folder.gradeId)) continue;
        if (gradeIds.contains(folder.gradeId)) continue;
        gradeIds.add(folder.gradeId);
      }
    } else {
      gradeIds = [_gradeFilter ?? current];
    }

    for (final gradeId in gradeIds) {
      final matches = [
        for (final folder in folders)
          if (!folder.custom && folder.gradeId == gradeId) folder,
      ];
      if (matches.isEmpty) continue;
      sections.add(
        _BagSection(
          id: gradeId,
          title: kGradeLabels[gradeId] ?? gradeId,
          folders: matches,
        ),
      );
    }
    return sections;
  }

  Widget _filterRow(BuildContext context, String currentGrade) {
    final theme = Theme.of(context);
    final label = _gradeFilter == null
        ? 'الصف الحالي'
        : _gradeFilter == '*'
            ? 'كل الصفوف'
            : kGradeLabels[_gradeFilter!] ?? _gradeFilter!;

    return Row(
      children: [
        Flexible(
          child: PopupMenuButton<String>(
            key: const Key('my-bag-grade-filter'),
            tooltip: context.tr('الصف الحالي'),
            onSelected: (value) =>
                setState(() => _gradeFilter = value.isEmpty ? null : value),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: '',
                child: TrText('الصف الحالي'),
              ),
              const PopupMenuItem<String>(
                key: Key('my-bag-filter-all'),
                value: '*',
                child: TrText('كل الصفوف'),
              ),
              for (final entry in kGradeLabels.entries)
                PopupMenuItem<String>(
                  key: Key('my-bag-filter-${entry.key}'),
                  value: entry.key,
                  child: TrText(entry.value),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ZakerSpacing.md,
                vertical: ZakerSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ZakerRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list, size: 18),
                  const SizedBox(width: ZakerSpacing.xs),
                  Flexible(
                    child: TrText(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: ZakerSpacing.sm),
        IconButton(
          key: const Key('my-bag-search'),
          tooltip: context.tr('بحث في شنطتي'),
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _search.clear();
          }),
        ),
      ],
    );
  }

  void _openLibrary() => context.push(ZakerRoutes.courses);

  void _openFolder(MyBagFolder folder) =>
      context.push(ZakerRoutes.bagFolderPath(folder.id));

  Future<void> _addCustomFolder() async {
    final name = await _promptName(
      title: 'مادة جديدة',
      fieldKey: const Key('my-bag-custom-name'),
      confirm: 'أضف',
    );
    if (name == null) return;
    await _run(
      () => ref.read(myBagControllerProvider.notifier).addCustomFolder(
            name: name,
            colorValue: kBagFolderColors.first.toARGB32(),
          ),
    );
  }

  Future<void> _renameFolder(MyBagFolder folder) async {
    final name = await _promptName(
      title: 'إعادة تسمية',
      fieldKey: const Key('my-bag-rename-field'),
      confirm: 'حفظ',
      initial: folder.name,
    );
    if (name == null) return;
    await _run(
      () => ref
          .read(myBagControllerProvider.notifier)
          .renameFolder(folder.id, name),
    );
  }

  Future<void> _pickColor(MyBagFolder folder) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('تغيير اللون'),
        content: Wrap(
          spacing: ZakerSpacing.md,
          runSpacing: ZakerSpacing.md,
          children: [
            for (final color in kBagFolderColors)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(color),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: color.toARGB32() == folder.colorValue
                        ? Border.all(width: 3, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
        ],
      ),
    );
    if (color == null) return;
    await _run(
      () => ref
          .read(myBagControllerProvider.notifier)
          .setFolderColor(folder.id, color.toARGB32()),
    );
  }

  Future<void> _deleteFolder(MyBagFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: TrText(context.trf('حذف «{0}»؟', [folder.name])),
        content: const TrText(
          'التسجيلات وصور البورد والروابط هتتحذف. ملفات PDF هتفضل في المكتبة من غير وسم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZakerColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const TrText('احذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref.read(myBagControllerProvider.notifier).deleteFolder(folder.id),
    );
    await _untagFolderPdfs(folder);
  }

  /// The dialog promises the folder's PDFs stay in the library «من غير وسم»:
  /// clear the tag on every document the folder owned, matching either the
  /// folder id recorded by «كوّن PDF» or the grade+subject tag an import sets.
  Future<void> _untagFolderPdfs(MyBagFolder folder) async {
    if (ref.read(myBagControllerProvider).folderById(folder.id) != null) {
      return; // The delete failed; the folder still owns its documents.
    }
    if (folder.pdfIds.isEmpty) return; // Nothing to untag, nothing to read.
    if (folder.gradeId.isEmpty && folder.subjectKey.isEmpty) return;
    final library = ref.read(pdfLibraryControllerProvider);
    final controller = ref.read(pdfLibraryControllerProvider.notifier);
    for (final id in folder.pdfIds) {
      final entry = library.entryById(id);
      if (entry == null) continue;
      final taggedHere = entry.sourceDocId.isNotEmpty
          ? entry.sourceDocId == folder.id
          : entry.gradeId == folder.gradeId &&
              entry.subjectKey == folder.subjectKey;
      if (!taggedHere) continue;
      await controller.clearSubjectTag(id);
    }
  }

  Future<String?> _promptName({
    required String title,
    required Key fieldKey,
    required String confirm,
    String? initial,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _NamePromptDialog(
        title: title,
        fieldKey: fieldKey,
        confirm: confirm,
        initial: initial,
      ),
    );
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('الحد الأقصى اتملى في المجلد ده.')),
      );
    }
  }
}

/// Asks for one name. Owns its controller so the field can finish its exit
/// animation before the controller is disposed.
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.fieldKey,
    required this.confirm,
    this.initial,
  });

  final String title;
  final Key fieldKey;
  final String confirm;
  final String? initial;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TrText(widget.title),
      content: TextFormField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: context.tr('اسم المادة')),
        onFieldSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: TrText(widget.confirm),
        ),
      ],
    );
  }
}

class _BagHero extends StatelessWidget {
  const _BagHero({required this.totals, required this.onOpenLibrary});

  final PocketTotals totals;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('my-bag-hero'),
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.cardValue),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            ZakerColors.backpack,
            Color.lerp(ZakerColors.backpack, Colors.black, 0.25)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedBackpack01,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'شنطتي',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ZakerSpacing.xs),
                    TrText(
                      'كل موادك في شنطة واحدة',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          Wrap(
            spacing: ZakerSpacing.md,
            runSpacing: ZakerSpacing.sm,
            children: [
              _HeroTotal(value: totals.pdfs, label: 'ملف PDF'),
              _HeroTotal(value: totals.voice, label: 'تسجيل'),
              _HeroTotal(value: totals.boards, label: 'صورة بورد'),
              _HeroTotal(value: totals.links, label: 'رابط'),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              key: const Key('my-bag-library-button'),
              onPressed: onOpenLibrary,
              child: const TrText('المكتبة الدراسية'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTotal extends StatelessWidget {
  const _HeroTotal({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: ZakerSpacing.xs),
        TrText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _AddFolderCard extends StatelessWidget {
  const _AddFolderCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('my-bag-add-custom'),
        onTap: onTap,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.lg,
            vertical: ZakerSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: ZakerRadius.card,
            border:
                Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedPlusSign,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              TrText(
                'أضف مادة',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
