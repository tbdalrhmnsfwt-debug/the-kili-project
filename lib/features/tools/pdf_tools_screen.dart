/// The PDF tools screen.
///
/// Shipped strings this screen is built from:
///   * `أدوات الـPDF`
///   * `PDF أو صور، أو من مكتبتك`
///   * `PDF وصور وباركود من الموبايل`
///   * `PDF بالحل`
///   * `PDF أو Word — الكتاب كله مرة واحدة`
///   * `أضف صوراً وملفات PDF بالترتيب المطلوب`
///
/// Every operation runs on-device: capture and OCR in [ScanScreen], question
/// sheets from the bundled books, a formatted book PDF for sharing or
/// printing, and a rasterising compressor for documents the user picks.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../core/asset_service.dart';
import '../../core/pdf_documents.dart';
import '../../core/pdf/pdf_library_index.dart';
import '../../core/quiz_generator.dart';
import '../../core/theme.dart';
import '../../models/ai.dart';
import '../../models/exam.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../providers/pdf_providers.dart';
import '../../widgets/common.dart';
import '../pdf/pdf_library_screen.dart';
import '../pdf/widgets/pdf_document_card.dart';
import '../pdf/widgets/pdf_import_button.dart';
import 'pdf_viewer_screen.dart';
import 'scan_screen.dart';
import '../../widgets/tr_text.dart';

/// The operations offered by the tools grid.
enum _PdfTool { viewer, images, solved, questions, formatted, print, compress }

/// The sources offered when adding a new sheet.
enum _SheetSource { camera, gallery, pdf, library }

/// The PDF / document tools screen.
class PdfToolsScreen extends ConsumerStatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  ConsumerState<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends ConsumerState<PdfToolsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final sheets = ref.watch(aiOutputsProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText('أدوات الـPDF')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const _LibrarySection(),
          if (_busy) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: ZakerSpacing.sm),
          ],
          const SectionHeader(title: 'أدواتك', icon: Icons.build_rounded),
          _ToolGrid(onSelect: _runTool),
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'ورقاتك',
            icon: Icons.description_rounded,
            actionLabel: 'جديد',
            onAction: _showAddSheet,
          ),
          if (sheets.isEmpty)
            const EmptyState(
              icon: Icons.description_outlined,
              title: 'مفيش ورقات لسه',
              message: 'اعمل ورقة جديدة من صور أو PDF.',
            )
          else
            for (final sheet in sheets)
              _SheetTile(sheet: sheet, onTap: () => _showSheetDetail(sheet)),
        ],
      ),
    );
  }

  /// Runs one grid operation.
  Future<void> _runTool(_PdfTool tool) async {
    if (_busy) {
      _toast('استنى العملية الحالية تخلص.');
      return;
    }
    if (tool == _PdfTool.viewer) {
      _openViewer();
    } else if (tool == _PdfTool.images) {
      _openScan();
    } else if (tool == _PdfTool.solved) {
      await _exportQuestions(withAnswers: true);
    } else if (tool == _PdfTool.questions) {
      await _exportQuestions(withAnswers: false);
    } else if (tool == _PdfTool.formatted) {
      await _exportBook(print: false);
    } else if (tool == _PdfTool.print) {
      await _exportBook(print: true);
    } else {
      await _compressPdf();
    }
  }

  /// Opens the on-device PDF reader.
  void _openViewer() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PdfViewerScreen()));
  }

  /// Opens the scan / OCR pipeline, which also exports its pages as a PDF.
  void _openScan() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
  }

  /// Builds and shares a question bank from the first readable book of the
  /// selected grade.
  Future<void> _exportQuestions({required bool withAnswers}) {
    return _run(() async {
      final grade = await _selectedGrade();
      if (!mounted) return;
      if (grade == null || grade.books.isEmpty) {
        _toast('مفيش كتب متاحة دلوقتي.');
        return;
      }

      final service = ref.read(assetServiceProvider);
      Book? source;
      List<ExamQuestion>? questions;
      for (final book in grade.books) {
        try {
          final json = await service.loadBook(book);
          final generated = generateClozeQuestions(
            book: book,
            lessons: service.parseLessons(json),
          );
          if (generated.isEmpty) continue;
          source = book;
          questions = generated;
          break;
        } catch (_) {
          // This book's payload is unavailable on the device; try the next.
        }
      }

      if (!mounted) return;
      if (source == null || questions == null) {
        _toast('مفيش كتاب مقروء فيه أسئلة كفاية للصف ده.');
        return;
      }

      final title = withAnswers
          ? 'أسئلة بالحل — ${source.title}'
          : 'أسئلة — ${source.title}';
      final bytes = await buildQuestionsPdf(
        title: title,
        subtitle:
            '${source.subject} • ${questions.length} سؤال • ${grade.label}',
        questions: questions,
        withAnswers: withAnswers,
      );
      if (!mounted) return;

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'zaker-'
            '${withAnswers ? 'solved' : 'questions'}-'
            '${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (!mounted) return;

      _saveOutput(
        kind: 'pdf',
        title: title,
        preview: '${questions.length} سؤال • ${source.subject}',
      );
      _toast('اتجهز الـPDF — اختار مكان الحفظ من الشير.');
    });
  }

  /// Builds a formatted PDF of a chosen book, then shares or prints it.
  Future<void> _exportBook({required bool print}) {
    return _run(() async {
      final book = await _pickBook();
      if (book == null || !mounted) return;

      final service = ref.read(assetServiceProvider);
      final List<Lesson> lessons;
      try {
        lessons = service.parseLessons(await service.loadBook(book));
      } on BookContentUnavailable {
        if (!mounted) return;
        _toast('«${book.title}» محتواه مشفّر — جرّب كتاب تاني.');
        return;
      }
      if (!mounted) return;
      if (lessons.isEmpty) {
        _toast('الكتاب ده مفيهوش دروس متاحة.');
        return;
      }

      final bytes = await buildBookPdf(book: book, lessons: lessons);
      if (!mounted) return;

      if (print) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: book.title,
        );
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'zaker-book-'
              '${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      }
      if (!mounted) return;

      _saveOutput(
        kind: 'pdf',
        title: book.title,
        preview: '${lessons.length} درس • ${book.subject}',
      );
      _toast(
        print
            ? 'اتفتح اختيار الطابعة.'
            : 'اتجهز الكتاب — اختار مكان الحفظ من الشير.',
      );
    });
  }

  /// Picks a PDF and rebuilds it at a lower resolution, sharing whichever
  /// copy is smaller.
  Future<void> _compressPdf() {
    return _run(() async {
      final data = await _pickPdfBytes();
      if (data == null || !mounted) return;

      _toast('بنجهز النسخة المضغوطة…');
      final compressed = await compressPdf(data);
      if (!mounted) return;

      final shrank = compressed.length < data.length;
      final output = shrank ? compressed : data;
      final name =
          'zaker-compressed-'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: output, filename: name);
      if (!mounted) return;

      _saveOutput(
        kind: 'pdf',
        title: 'نسخة مضغوطة',
        preview: shrank
            ? '${_size(data.length)} ← ${_size(output.length)}'
            : 'الملف أصلاً مضغوط (${_size(data.length)})',
      );
      _toast(
        shrank
            ? 'اتضغط الملف — بقى ${_size(output.length)}.'
            : 'الملف أصلاً مضغوط — شاركناه زي ما هو.',
      );
    });
  }

  /// Imports the text of a picked PDF as a new sheet.
  Future<void> _importPdf() {
    return _run(() async {
      final data = await _pickPdfBytes();
      if (data == null || !mounted) return;

      sf.PdfDocument? document;
      try {
        document = sf.PdfDocument(inputBytes: data);
        final text = sf.PdfTextExtractor(document).extractText().trim();
        if (text.isEmpty) {
          _toast('الملف مفيهوش نص — لو صور، استخدم المسح الضوئي.');
          return;
        }
        _saveOutput(
          kind: 'pdf',
          title: 'ورقة مستوردة',
          preview: text.length > 1200 ? '${text.substring(0, 1200)}…' : text,
        );
        _toast('اتضافت الورقة من الـPDF.');
      } catch (_) {
        _toast('مقدرناش نقرا ملف الـPDF ده.');
      } finally {
        document?.dispose();
      }
    });
  }

  /// Adds a bundled library book as a sheet with its lesson summary.
  Future<void> _addFromLibrary() {
    return _run(() async {
      final book = await _pickBook();
      if (book == null || !mounted) return;

      final service = ref.read(assetServiceProvider);
      try {
        final lessons = service.parseLessons(await service.loadBook(book));
        final summary = lessons.isEmpty
            ? '${book.subject} • ${book.pages} صفحة'
            : '${lessons.length} درس • ${book.subject}\n'
                  '${_preview(lessons.first.narrative)}';
        _saveOutput(kind: 'sheet', title: book.title, preview: summary);
        _toast('اتضافت «${book.title}» لورقاتك.');
      } on BookContentUnavailable {
        _toast('«${book.title}» محتواه مشفّر — جرّب كتاب تاني.');
      } catch (e) {
        _toast('مقدرناش نفتح الكتاب: $e');
      }
    });
  }

  /// Asks for a new sheet's source and routes it to the matching flow.
  Future<void> _showAddSheet() async {
    if (_busy) {
      _toast('استنى العملية الحالية تخلص.');
      return;
    }
    final source = await showModalBottomSheet<_SheetSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (context) => const _AddSheetSheet(),
    );
    if (!mounted || source == null) return;

    if (source == _SheetSource.camera || source == _SheetSource.gallery) {
      _openScan();
    } else if (source == _SheetSource.pdf) {
      await _importPdf();
    } else {
      await _addFromLibrary();
    }
  }

  /// The selected grade, falling back to the first one with content.
  Future<Grade?> _selectedGrade() async {
    final grades = await ref.read(gradesProvider.future);
    if (grades.isEmpty) return null;
    final id = ref.read(selectedGradeProvider);
    return grades.firstWhere((g) => g.id == id, orElse: () => grades.first);
  }

  /// Shows the books of the selected grade and returns the one picked.
  Future<Book?> _pickBook() async {
    final grade = await _selectedGrade();
    if (!mounted) return null;
    if (grade == null || grade.books.isEmpty) {
      _toast('مفيش كتب متاحة دلوقتي.');
      return null;
    }

    return showModalBottomSheet<Book>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  0,
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                ),
                child: TrText(
                  'اختار الكتاب',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final book in grade.books)
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: TrText(book.title),
                        subtitle: TrText(
                          [
                            book.subject,
                            book.variant,
                          ].where((s) => s.isNotEmpty).join(' • '),
                        ),
                        onTap: () => Navigator.of(context).pop(book),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: ZakerSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks a PDF and returns its bytes, or null when the user cancels.
  Future<Uint8List?> _pickPdfBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }

  /// Short text preview for a library sheet.
  String _preview(String text) {
    final clean = text.trim().replaceAll(RegExp(r'[*_`#>]+'), '');
    return clean.length > 220 ? '${clean.substring(0, 220)}…' : clean;
  }

  /// Human-readable file size.
  String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }

  /// Adds [AiOutput] so generated documents show under "ورقاتك".
  void _saveOutput({
    required String kind,
    required String title,
    required String preview,
  }) {
    final outputs = ref.read(aiOutputsProvider);
    ref.read(aiOutputsProvider.notifier).state = [
      AiOutput(
        id: 'pdf-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        title: title,
        createdAt: DateTime.now(),
        preview: preview,
      ),
      ...outputs,
    ];
  }

  /// Runs [body] while showing the progress bar, reporting any exception.
  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      _toast('حصلت مشكلة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }

  void _showSheetDetail(AiOutput sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TrText(
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
                Flexible(
                  child: SingleChildScrollView(
                    child: TrText(
                      sheet.preview.isEmpty ? 'مفيش تفاصيل' : sheet.preview,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ZakerSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const TrText('تم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «ملفاتي» above the tools grid: the most recent few documents plus a way
/// into the full library. Hidden while the library is empty so the tools grid
/// stays the first thing on the screen.
class _LibrarySection extends ConsumerWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(pdfLibraryControllerProvider);
    final entries = index.query(
      sort: PdfSort.addedAt,
      descending: true,
      limit: 6,
    );
    if (entries.isEmpty) return const SizedBox.shrink();
    final store = ref.watch(pdfLibraryStoreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'ملفاتي',
          icon: Icons.folder_special_outlined,
          actionLabel: 'عرض الكل',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PdfLibraryScreen()),
          ),
        ),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length + 1,
            separatorBuilder: (context, position) =>
                const SizedBox(width: ZakerSpacing.sm),
            itemBuilder: (context, position) {
              if (position == entries.length) {
                return SizedBox(
                  width: 140,
                  child: _ImportTile(onTap: () => importPdfFiles(context, ref)),
                );
              }
              final entry = entries[position];
              return SizedBox(
                width: 150,
                child: PdfDocumentCard(
                  entry: entry,
                  layout: PdfDocumentCardLayout.grid,
                  available: store.baseFile(entry.id).existsSync(),
                  onOpen: () => openPdfDocument(context, entry),
                  onRename: () => renamePdfDocument(context, ref, entry),
                  onDelete: () => deletePdfDocument(context, ref, entry),
                  onShare: () => sharePdfDocument(context, ref, entry),
                  onDetails: () => showPdfDocumentDetails(context, ref, entry),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZakerSpacing.xl),
      ],
    );
  }
}

/// The "add a PDF" tile at the end of the recent row.
class _ImportTile extends StatelessWidget {
  const _ImportTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: ZakerRadius.card,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: ZakerRadius.card,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              'ضيف PDF',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grid of PDF operations.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.onSelect});

  final ValueChanged<_PdfTool> onSelect;

  static const _tools = <({_PdfTool tool, String label, IconData icon})>[
    (
      tool: _PdfTool.viewer,
      label: 'اعرض PDF',
      icon: Icons.auto_stories_rounded,
    ),
    (tool: _PdfTool.images, label: 'PDF من صور', icon: Icons.image_outlined),
    (tool: _PdfTool.solved, label: 'PDF بالحل', icon: Icons.task_alt_rounded),
    (
      tool: _PdfTool.formatted,
      label: 'PDF منسق',
      icon: Icons.format_align_right_rounded,
    ),
    (
      tool: _PdfTool.questions,
      label: 'PDF أسئلة بس',
      icon: Icons.quiz_outlined,
    ),
    (tool: _PdfTool.compress, label: 'ضغط', icon: Icons.compress_rounded),
    (tool: _PdfTool.print, label: 'طباعة', icon: Icons.print_outlined),
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
        childAspectRatio: 0.95,
      ),
      itemCount: _tools.length,
      itemBuilder: (context, index) {
        final item = _tools[index];
        return FeatureTile(
          title: item.label,
          icon: item.icon,
          onTap: () => onSelect(item.tool),
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
            TrText(
              'أضف صوراً وملفات PDF بالترتيب المطلوب',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              'اختار صور أو ملفات، رتّبها، وبعدها تقدر تعمل PDF منهم.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.lg),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.sm,
              children: [
                _SourceButton(
                  label: 'صور',
                  icon: Icons.photo_library_outlined,
                  onTap: () => Navigator.of(context).pop(_SheetSource.gallery),
                ),
                _SourceButton(
                  label: 'ملفات PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  onTap: () => Navigator.of(context).pop(_SheetSource.pdf),
                ),
                _SourceButton(
                  label: 'من المكتبة',
                  icon: Icons.folder_open_outlined,
                  onTap: () => Navigator.of(context).pop(_SheetSource.library),
                ),
                _SourceButton(
                  label: 'الكاميرا',
                  icon: Icons.photo_camera_outlined,
                  onTap: () => Navigator.of(context).pop(_SheetSource.camera),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const TrText('تم'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A source picker button.
class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: TrText(label),
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
                    TrText(
                      sheet.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TrText(
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
