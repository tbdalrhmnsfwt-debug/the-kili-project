/// «ملفاتي» — the private PDF library.
///
/// Everything here is local: imports are copies in app-private storage, and
/// the only way a file leaves the device is the user tapping «مشاركة».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pdf/pdf_library_index.dart';
import '../../core/theme.dart';
import '../../models/pdf_document.dart';
import '../../providers/pdf_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'widgets/pdf_document_card.dart';
import 'widgets/pdf_import_button.dart';

/// Browse, search and manage the local PDFs.
class PdfLibraryScreen extends ConsumerStatefulWidget {
  const PdfLibraryScreen({super.key});

  @override
  ConsumerState<PdfLibraryScreen> createState() => _PdfLibraryScreenState();
}

class _PdfLibraryScreenState extends ConsumerState<PdfLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  PdfSort _sort = PdfSort.addedAt;
  PdfDocumentCardLayout _layout = PdfDocumentCardLayout.grid;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    // Re-read the catalog; entries whose file vanished stay listed so the
    // card can offer removal instead of silently losing the document.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pdfLibraryControllerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await importPdfFiles(context, ref);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(pdfLibraryControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const TrText('ملفاتي'),
        actions: [
          IconButton(
            tooltip: 'ضيف PDF',
            onPressed: _importing ? null : _import,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: index.entries.isEmpty ? _empty() : _filled(index),
    );
  }

  Widget _empty() {
    return EmptyState(
      icon: Icons.folder_open_rounded,
      title: 'لسه مفيش ملفات',
      message: 'ضيف أول PDF من الموبايل — كل حاجة بتفضل على جهازك.',
      action: FilledButton.icon(
        onPressed: _importing ? null : _import,
        icon: const Icon(Icons.add_rounded),
        label: const TrText('ضيف PDF'),
      ),
    );
  }

  Widget _filled(PdfLibraryIndex index) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.sm,
              ZakerSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'دوّر على ملف',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: ZakerRadius.card,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: ZakerSpacing.sm,
              right: ZakerSpacing.sm,
            ),
            child: Row(
              children: [
                PopupMenuButton<PdfSort>(
                  tooltip: 'ترتيب',
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: PdfSort.addedAt,
                      child: TrText('الأحدث'),
                    ),
                    PopupMenuItem(value: PdfSort.name, child: TrText('الاسم')),
                    PopupMenuItem(value: PdfSort.size, child: TrText('الحجم')),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: _layout == PdfDocumentCardLayout.grid
                      ? 'عرض كقائمة'
                      : 'عرض كشبكة',
                  onPressed: () => setState(() {
                    _layout = _layout == PdfDocumentCardLayout.grid
                        ? PdfDocumentCardLayout.list
                        : PdfDocumentCardLayout.grid;
                  }),
                  icon: Icon(
                    _layout == PdfDocumentCardLayout.grid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            labelColor: theme.colorScheme.primary,
            tabs: const [
              Tab(child: TrText('الحديثة')),
              Tab(child: TrText('كل الملفات')),
              Tab(child: TrText('المفضلة')),
            ],
          ),
          if (_importing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              children: [
                _browse(index, favoritesOnly: false, limit: 12),
                _browse(index, favoritesOnly: false),
                _browse(index, favoritesOnly: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _browse(
    PdfLibraryIndex index, {
    required bool favoritesOnly,
    int? limit,
  }) {
    final entries = index.query(
      search: _search.text,
      sort: _sort,
      descending: true,
      favoritesOnly: favoritesOnly,
      limit: limit,
    );
    if (entries.isEmpty) {
      return EmptyState(
        icon: favoritesOnly
            ? Icons.star_border_rounded
            : Icons.search_off_rounded,
        title: favoritesOnly ? 'مفيش ملفات في المفضلة' : 'مفيش نتايج',
        message: favoritesOnly
            ? 'علّم ملف بنجمة عشان تلاقيه هنا.'
            : 'جرّب كلمة تانية.',
      );
    }
    if (_layout == PdfDocumentCardLayout.list) {
      return ListView.separated(
        padding: ZakerSpacing.screen,
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: ZakerSpacing.sm),
        itemBuilder: (context, position) =>
            _card(entries[position], PdfDocumentCardLayout.list),
      );
    }
    return GridView.builder(
      padding: ZakerSpacing.screen,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: ZakerSpacing.sm,
        crossAxisSpacing: ZakerSpacing.sm,
        childAspectRatio: 0.9,
      ),
      itemCount: entries.length,
      itemBuilder: (context, position) =>
          _card(entries[position], PdfDocumentCardLayout.grid),
    );
  }

  Widget _card(PdfDocumentEntry entry, PdfDocumentCardLayout layout) {
    final store = ref.watch(pdfLibraryStoreProvider);
    return PdfDocumentCard(
      entry: entry,
      layout: layout,
      available: store.baseFile(entry.id).existsSync(),
      onOpen: () => openPdfDocument(context, entry),
      onRename: () => renamePdfDocument(context, ref, entry),
      onDelete: () => deletePdfDocument(context, ref, entry),
      onShare: () => sharePdfDocument(context, ref, entry),
      onDetails: () => showPdfDocumentDetails(context, ref, entry),
    );
  }
}
