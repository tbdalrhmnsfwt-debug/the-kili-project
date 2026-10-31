/// The PDF Studio library: a dark dashboard for everything the student keeps.
///
/// The old light [PdfLibraryScreen] is still exported from
/// `features/pdf/pdf_library_screen.dart`; this screen is the studio skin the
/// `/pdf-library` route renders. Both share the same controller, repository,
/// picker and file helpers, so there is one source of truth for the catalog.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/pdf/pdf_annotations.dart';
import '../../../core/pdf/pdf_export_manager.dart';
import '../../../core/pdf/pdf_library_controller.dart';
import '../../../core/pdf/pdf_library_index.dart';
import '../../../core/router.dart';
import '../../../core/theme/pdf_studio_theme.dart';
import '../../../models/pdf_document.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/pdf_providers.dart';
import '../../../widgets/tr_text.dart';
import '../widgets/pdf_document_card.dart'
    show
        deletePdfDocument,
        formatPdfDate,
        formatPdfSize,
        openPdfDocument,
        renamePdfDocument;
import '../widgets/pdf_import_button.dart' show importPdfFiles;

/// The dark, studio-styled library.
class PdfStudioLibraryScreen extends ConsumerStatefulWidget {
  const PdfStudioLibraryScreen({super.key});

  @override
  ConsumerState<PdfStudioLibraryScreen> createState() =>
      _PdfStudioLibraryScreenState();
}

class _PdfStudioLibraryScreenState
    extends ConsumerState<PdfStudioLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _query = '';
  bool _favoritesOnly = false;
  bool _showAll = false;
  bool _busy = false;

  static const int _storageBudgetBytes = 32 * 1024 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(pdfLibraryControllerProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(pdfLibraryControllerProvider);
    final entries = library.query(
      search: _query,
      sort: PdfSort.addedAt,
      favoritesOnly: _favoritesOnly,
    );
    final recent = _showAll ? entries : entries.take(5).toList();
    final used = library.entries.fold<int>(
      0,
      (total, entry) => total + entry.sizeBytes,
    );

    return Theme(
      data: PdfStudioTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: PdfStudioColors.background,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: PdfStudioColors.pageGradient,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: PdfStudioColors.blue,
                backgroundColor: PdfStudioColors.surface,
                onRefresh: () async {
                  await ref
                      .read(pdfLibraryControllerProvider.notifier)
                      .refresh();
                },
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          14,
                          20,
                          0,
                        ),
                        child: _Header(onMore: _openMoreSheet),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          18,
                          20,
                          0,
                        ),
                        child: _SearchField(
                          controller: _search,
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          onClear: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          18,
                          20,
                          0,
                        ),
                        child: _QuickActions(
                          busy: _busy,
                          onCreate: _createNewPdf,
                          onCloud: () => _import(cloud: true),
                          onScan: () => context.push(ZakerRoutes.scan),
                          onImport: _import,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          24,
                          20,
                          0,
                        ),
                        child: _SectionHeader(
                          title: 'الملفات الأخيرة',
                          count: entries.length,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FilterChip(
                                selected: _favoritesOnly,
                                icon: Icons.star_rounded,
                                label: 'المفضلة',
                                onTap: () => setState(
                                  () => _favoritesOnly = !_favoritesOnly,
                                ),
                              ),
                              if (entries.length > 5) ...[
                                const SizedBox(width: 4),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showAll = !_showAll),
                                  child: TrText(
                                    _showAll ? 'أقل' : 'عرض الكل',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (entries.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: _EmptyLibrary(
                            filtered: _query.isNotEmpty || _favoritesOnly,
                            onImport: _import,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index.isOdd) {
                                return const SizedBox(height: 10);
                              }
                              final entry = recent[index ~/ 2];
                              return _DocumentRow(
                                entry: entry,
                                onOpen: () => openPdfDocument(context, entry),
                                onFavorite: () => _toggleFavorite(entry),
                                onRename: () => _rename(entry),
                                onDelete: () => _delete(entry),
                                onShare: () => _share(entry),
                                onDetails: () => _details(entry),
                              );
                            },
                            childCount:
                                recent.isEmpty ? 0 : recent.length * 2 - 1,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          22,
                          20,
                          0,
                        ),
                        child: _StorageCard(
                            usedBytes: used, budget: _storageBudgetBytes),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _StudioNav(
            onHome: () => context.go(ZakerRoutes.home),
            onDocuments: () => _scrollTop(),
            onTools: () => context.push(ZakerRoutes.pdfTools),
            onFiles: _import,
            onMore: _openMoreSheet,
          ),
        ),
      ),
    );
  }

  void _scrollTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _createNewPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final document = sf.PdfDocument();
      document.pageSettings.size = const Size(595, 842);
      document.pages.add();
      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();
      final result =
          await ref.read(pdfLibraryControllerProvider.notifier).import([
        PdfImportSource(
          name: 'مستند جديد.pdf',
          sizeBytes: bytes.length,
          openRead: () => Stream.value(bytes),
        ),
      ]);
      if (!mounted) return;
      if (result.imported.isNotEmpty) {
        await openPdfDocument(context, result.imported.first);
      } else {
        _toast('مقدرناش ننشئ المستند.');
      }
    } on Object {
      if (mounted) _toast('مقدرناش ننشئ المستند.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import({bool cloud = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (cloud) {
        _toast('اختَر الملف من Google Drive أو OneDrive أو أي خدمة تخزين.');
      }
      await importPdfFiles(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFavorite(PdfDocumentEntry entry) {
    return ref
        .read(pdfLibraryControllerProvider.notifier)
        .setFavorite(entry.id, !entry.favorite);
  }

  Future<void> _rename(PdfDocumentEntry entry) async {
    await renamePdfDocument(context, ref, entry);
  }

  Future<void> _delete(PdfDocumentEntry entry) async {
    await deletePdfDocument(context, ref, entry);
  }

  Future<void> _share(PdfDocumentEntry entry) async {
    final store = ref.read(pdfLibraryStoreProvider);
    final file = store.baseFile(entry.id);
    if (!file.existsSync()) {
      _toast('الملف مش موجود على الجهاز.');
      return;
    }
    await Share.shareXFiles([XFile(file.path)], subject: entry.displayName);
  }

  Future<void> _details(PdfDocumentEntry entry) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final style = TextStyle(
          fontSize: 13,
          height: 1.6,
          color: PdfStudioColors.muted,
        );
        return AlertDialog(
          title: TrText(entry.displayName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'النوع: PDF',
                  style: style,
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  'الحجم: ${formatPdfSize(entry.sizeBytes)}',
                  style: style,
                  textDirection: TextDirection.rtl,
                ),
                if (entry.pageCount != null)
                  Text(
                    'الصفحات: ${entry.pageCount}',
                    style: style,
                    textDirection: TextDirection.rtl,
                  ),
                Text(
                  'أُضيف: ${formatPdfDate(entry.addedAt)}',
                  style: style,
                  textDirection: TextDirection.rtl,
                ),
                if (entry.lastOpenedAt != null)
                  Text(
                    'آخر قراءة: ${formatPdfDate(entry.lastOpenedAt!)}',
                    style: style,
                    textDirection: TextDirection.rtl,
                  ),
                Text(
                  'ملاحظات محفوظة: ${entry.annotationCount}',
                  style: style,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TrText('تمام'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMoreSheet() async {
    await PdfStudioTheme.showSheet<void>(
      context: context,
      builder: (sheetContext) => _MoreSheet(
        onRestore: () {
          Navigator.of(sheetContext).pop();
          unawaited(_restoreProject());
        },
        onTools: () {
          Navigator.of(sheetContext).pop();
          context.push(ZakerRoutes.pdfTools);
        },
        onScan: () {
          Navigator.of(sheetContext).pop();
          context.push(ZakerRoutes.scan);
        },
        onHome: () {
          Navigator.of(sheetContext).pop();
          context.go(ZakerRoutes.home);
        },
      ),
    );
  }

  Future<void> _restoreProject() async {
    if (_busy) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      _toast('مقدرناش نقرأ الحزمة.');
      return;
    }
    setState(() => _busy = true);
    try {
      final project = PdfExportManager().readProjectPackage(bytes);
      final store = ref.read(pdfLibraryStoreProvider);
      final result =
          await ref.read(pdfLibraryControllerProvider.notifier).import([
        PdfImportSource(
          name: '${project.documentName}.pdf',
          sizeBytes: project.sourcePdf.length,
          openRead: () => Stream.value(project.sourcePdf),
        ),
      ]);
      if (!mounted) return;
      if (result.imported.isEmpty) {
        _toast('مقدرناش نستورد الملف الأصلي.');
        return;
      }
      final entry = result.imported.first;
      final restored = <PdfAnnotation>[];
      for (final annotation in project.annotations) {
        var mediaPath = annotation.mediaPath;
        if (annotation.kind.hasMedia) {
          final match = _mediaFor(project.attachments, annotation);
          if (match != null) {
            final target = store.annotationAsset(
              entry.id,
              '${annotation.id}.${annotation.mediaExtension}',
            );
            await target.parent.create(recursive: true);
            await target.writeAsBytes(match, flush: true);
            mediaPath = target.path;
          }
        }
        restored.add(annotation.copyWith(mediaPath: mediaPath));
      }
      await ref.read(localStoreProvider).setString(
            pdfAnnotationsStoreKey(entry.id),
            encodePdfAnnotations(restored),
          );
      await ref.read(pdfLibraryControllerProvider.notifier).markOpened(
            entry.id,
            page: project.pageCount == null
                ? project.lastPage
                : project.lastPage.clamp(1, project.pageCount!).toInt(),
            zoom: project.lastZoom,
            quarterTurns: project.quarterTurns,
          );
      if (!mounted) return;
      _toast('تم استعادة المشروع بكل ملاحظاته.');
      await ref.read(pdfLibraryControllerProvider.notifier).refresh();
    } on PdfProjectException catch (error) {
      if (mounted) _toast(error.message);
    } on Object {
      if (mounted) _toast('مقدرناش نستعيد الحزمة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Uint8List? _mediaFor(
    Map<String, Uint8List> attachments,
    PdfAnnotation annotation,
  ) {
    final prefix = 'attachments/${annotation.id}.';
    for (final entry in attachments.entries) {
      if (entry.key.startsWith(prefix)) return entry.value;
    }
    return null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }
}

// ------------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [PdfStudioColors.violet, PdfStudioColors.blue],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: PdfStudioColors.violet.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'مكتبة PDF',
                style: TextStyle(
                  color: PdfStudioColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              TrText(
                'ملفاتك وملاحظاتك في مكان واحد',
                style: TextStyle(
                  color: PdfStudioColors.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'المزيد',
          onPressed: onMore,
          style: IconButton.styleFrom(
            backgroundColor: PdfStudioColors.surface,
            side: const BorderSide(color: PdfStudioColors.stroke),
          ),
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: PdfStudioColors.text,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontFamily: PdfStudioTheme.font,
        color: PdfStudioColors.text,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'ابحث في ملفات PDF...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
      ),
    );
  }
}

// --------------------------------------------------------------- quick actions

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.busy,
    required this.onCreate,
    required this.onCloud,
    required this.onScan,
    required this.onImport,
  });

  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onCloud;
  final VoidCallback onScan;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrText(
          'إجراءات سريعة',
          style: TextStyle(
            color: PdfStudioColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 82,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickCard(
                label: 'إنشاء PDF جديد',
                subtitle: 'صفحة بيضاء',
                icon: Icons.add_rounded,
                gradient: const [PdfStudioColors.violet, Color(0xFF5B3FE0)],
                busy: busy,
                onTap: onCreate,
              ),
              _QuickCard(
                label: 'إضافة من السحابة',
                subtitle: 'Drive أو OneDrive',
                icon: Icons.cloud_outlined,
                gradient: const [PdfStudioColors.blue, Color(0xFF2D5BE3)],
                onTap: onCloud,
              ),
              _QuickCard(
                label: 'مسح ضوئي إلى PDF',
                subtitle: 'كاميرا + OCR',
                icon: Icons.document_scanner_outlined,
                gradient: const [PdfStudioColors.cyan, Color(0xFF1D8FB8)],
                onTap: onScan,
              ),
              _QuickCard(
                label: 'استيراد من الجهاز',
                subtitle: 'ملفات PDF',
                icon: Icons.folder_open_rounded,
                gradient: const [
                  PdfStudioColors.yellow,
                  Color(0xFFD8A92F),
                ],
                darkInk: true,
                onTap: onImport,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.busy = false,
    this.darkInk = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool busy;
  final bool darkInk;

  @override
  Widget build(BuildContext context) {
    final ink = darkInk ? const Color(0xFF241B00) : Colors.white;
    final sub = darkInk
        ? const Color(0xFF3D2F00).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.78);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(13, 11, 13, 11),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: darkInk ? 0.14 : 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: busy
                        ? Padding(
                            padding: const EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ink,
                            ),
                          )
                        : Icon(icon, color: ink, size: 21),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: PdfStudioTheme.font,
                            color: ink,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: PdfStudioTheme.font,
                            color: sub,
                            fontSize: 9.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- recent files

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
  });

  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TrText(
          title,
          style: const TextStyle(
            color: PdfStudioColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: PdfStudioColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: PdfStudioColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PdfStudioColors.yellow.withValues(alpha: 0.16)
          : PdfStudioColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? PdfStudioColors.yellow.withValues(alpha: 0.55)
                  : PdfStudioColors.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color:
                    selected ? PdfStudioColors.yellow : PdfStudioColors.muted,
              ),
              const SizedBox(width: 5),
              TrText(
                label,
                style: TextStyle(
                  color:
                      selected ? PdfStudioColors.yellow : PdfStudioColors.muted,
                  fontSize: 11,
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

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.entry,
    required this.onOpen,
    required this.onFavorite,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.onDetails,
  });

  final PdfDocumentEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final when = entry.lastOpenedAt ?? entry.addedAt;
    final meta = '${_relativeTime(when)} • ${formatPdfSize(entry.sizeBytes)}';
    return Material(
      color: PdfStudioColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 6, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PdfStudioColors.stroke),
          ),
          child: Row(
            children: [
              const _PdfBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TrText(
                            entry.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PdfStudioColors.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (entry.favorite)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(end: 2),
                            child: Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: PdfStudioColors.yellow,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.pageCount != null) ...[
                          Text(
                            '${entry.pageCount} صفحة',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: PdfStudioColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: PdfStudioColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: PdfStudioColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الملف',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: PdfStudioColors.muted,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'open':
                      onOpen();
                    case 'favorite':
                      onFavorite();
                    case 'rename':
                      onRename();
                    case 'share':
                      onShare();
                    case 'details':
                      onDetails();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: TrText('فتح')),
                  PopupMenuItem(
                    value: 'favorite',
                    child: TrText(
                      entry.favorite ? 'شيل من المفضلة' : 'ضيف للمفضلة',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: TrText('إعادة تسمية'),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: TrText('مشاركة'),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: TrText('التفاصيل'),
                  ),
                  const PopupMenuItem(value: 'delete', child: TrText('حذف')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfBadge extends StatelessWidget {
  const _PdfBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFF6B6B), PdfStudioColors.pdfRed],
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: PdfStudioColors.pdfRed.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_rounded, size: 17, color: Colors.white),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.filtered, required this.onImport});

  final bool filtered;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: PdfStudioColors.card(),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: PdfStudioColors.violet.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: PdfStudioColors.violetText,
              size: 27,
            ),
          ),
          const SizedBox(height: 12),
          TrText(
            filtered ? 'مفيش نتائج مطابقة' : 'مفيش ملفات PDF لسه',
            style: const TextStyle(
              color: PdfStudioColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          TrText(
            filtered
                ? 'جرّب كلمة بحث تانية أو شيل فلتر المفضلة.'
                : 'ابدأ باستيراد ملف من جهازك أو أنشئ مستندًا جديدًا.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PdfStudioColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (!filtered) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const TrText('استيراد PDF'),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ storage

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.usedBytes, required this.budget});

  final int usedBytes;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : (usedBytes / budget).clamp(0.0, 1.0);
    final percent = (ratio * 100).clamp(0, 100).toDouble();
    final shownPercent =
        usedBytes > 0 && percent < 1 ? '<1' : percent.round().toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: PdfStudioColors.storageGradient,
        borderRadius: BorderRadius.circular(PdfStudioColors.cardRadius),
        border: Border.all(color: PdfStudioColors.stroke),
        boxShadow: PdfStudioColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PdfStudioColors.blue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storage_rounded,
                  color: PdfStudioColors.blueText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'التخزين',
                      style: TextStyle(
                        color: PdfStudioColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    TrText(
                      'مساحة مكتبة PDF على الجهاز',
                      style: TextStyle(
                        color: PdfStudioColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$shownPercent%',
                style: const TextStyle(
                  color: PdfStudioColors.cyanText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: usedBytes == 0 ? 0 : ratio.clamp(0.01, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF0B1B38),
              valueColor: const AlwaysStoppedAnimation<Color>(
                PdfStudioColors.blue,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                '${_formatStorage(usedBytes)} / ${_formatStorage(budget)}',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: PdfStudioColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              const TrText(
                'الملفات الأصلية مش بتتأثر',
                style: TextStyle(
                  color: PdfStudioColors.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatStorage(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} غ.ب';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} ك.ب';
  return '$bytes بايت';
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return 'الآن';
  if (difference.inMinutes < 60) {
    return _ago(difference.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق');
  }
  if (difference.inHours < 24) {
    return _ago(difference.inHours, 'ساعة', 'ساعتين', 'ساعات');
  }
  if (difference.inDays < 30) {
    return _ago(difference.inDays, 'يوم', 'يومين', 'أيام');
  }
  if (difference.inDays < 365) {
    final months = difference.inDays ~/ 30;
    return _ago(months, 'شهر', 'شهرين', 'شهور');
  }
  final years = difference.inDays ~/ 365;
  return _ago(years, 'سنة', 'سنتين', 'سنين');
}

String _ago(int value, String one, String two, String many) {
  if (value == 1) return 'منذ $one';
  if (value == 2) return 'منذ $two';
  if (value <= 10) return 'منذ $value $many';
  return 'منذ $value $one';
}

// ---------------------------------------------------------------- bottom nav

class _StudioNav extends StatelessWidget {
  const _StudioNav({
    required this.onHome,
    required this.onDocuments,
    required this.onTools,
    required this.onFiles,
    required this.onMore,
  });

  final VoidCallback onHome;
  final VoidCallback onDocuments;
  final VoidCallback onTools;
  final VoidCallback onFiles;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem('الرئيسية', Icons.home_rounded, onHome),
      _NavItem('المستندات', Icons.folder_copy_rounded, onDocuments,
          selected: true),
      _NavItem('أدوات', Icons.build_circle_outlined, onTools),
      _NavItem('الملفات', Icons.folder_open_rounded, onFiles),
      _NavItem('المزيد', Icons.more_horiz_rounded, onMore),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: PdfStudioColors.glass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PdfStudioColors.stroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: item.selected,
                    label: item.label,
                    child: InkWell(
                      onTap: item.onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: item.selected
                              ? PdfStudioColors.blue.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 21,
                              color: item.selected
                                  ? PdfStudioColors.blueText
                                  : PdfStudioColors.muted,
                            ),
                            const SizedBox(height: 3),
                            TrText(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: item.selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: item.selected
                                    ? PdfStudioColors.blueText
                                    : PdfStudioColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.onTap, {this.selected = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
}

// ------------------------------------------------------------------ more sheet

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.onRestore,
    required this.onTools,
    required this.onScan,
    required this.onHome,
  });

  final VoidCallback onRestore;
  final VoidCallback onTools;
  final VoidCallback onScan;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MoreItem(
        'استعادة حزمة مشروع',
        'افتح .zakerpdf بكل ملاحظاته ووسائطه',
        Icons.inventory_2_outlined,
        PdfStudioColors.violetText,
        onRestore,
      ),
      _MoreItem(
        'أدوات PDF',
        'ضغط، مسح ضوئي، ورقات وأسئلة',
        Icons.build_circle_outlined,
        PdfStudioColors.cyanText,
        onTools,
      ),
      _MoreItem(
        'مسح ضوئي إلى PDF',
        'صوّر الورقة وحوّلها لنص قابل للبحث',
        Icons.document_scanner_outlined,
        PdfStudioColors.yellow,
        onScan,
      ),
      _MoreItem(
        'الرئيسية',
        'رجوع للوحة رفيق الطالب',
        Icons.home_rounded,
        PdfStudioColors.blueText,
        onHome,
      ),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TrText(
              'المزيد',
              style: TextStyle(
                color: PdfStudioColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const TrText(
              'كل أدوات مكتبتك في مكان واحد.',
              style: TextStyle(
                color: PdfStudioColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MoreTile(item: item),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PdfStudioColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(item.icon, color: item.color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      item.title,
                      style: const TextStyle(
                        color: PdfStudioColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PdfStudioColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: PdfStudioColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
