/// The native PDF reader.
///
/// Android's `PdfRenderer` paints the pages (Task 9's viewport); this file
/// owns everything around the page: resolving which file to open, the
/// password prompt for locked documents, the chrome that hides on tap, and
/// the promise that a transient document leaves nothing behind.
///
/// Privacy notes:
///   * A password is passed straight to the native open call and never stored,
///     logged or put in a message.
///   * In-memory bytes are written to a session temp file and deleted when the
///     reader closes; library copies are never modified.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/pdf/pdf_page_geometry.dart';
import '../../core/pdf/pdf_render_channel.dart';
import '../../core/pdf/pdf_text_map.dart';
import '../../core/theme.dart';
import '../../models/pdf_document.dart';
import '../../providers/pdf_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'widgets/pdf_reader_viewport.dart';
import 'widgets/pdf_search_sheet.dart';

/// What the reader is allowed to do. Annotate and sign arrive with Plan 2.
enum PdfReaderMode { read }

/// Opens a PDF from the library, a path, or in-memory bytes.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({
    super.key,
    this.path,
    this.title,
    this.bytes,
    this.fileName,
    this.docId,
    this.mode = PdfReaderMode.read,
  });

  /// A local file path to open.
  final String? path;

  /// The fallback title when no library entry names the document.
  final String? title;

  /// Bytes to render, materialised into a session temp file.
  final Uint8List? bytes;

  /// The picked file's name, used for titles and sharing.
  final String? fileName;

  /// The library entry to open, when the document belongs to «ملفاتي».
  final String? docId;

  final PdfReaderMode mode;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  late final PdfRenderChannel _channel;
  PdfRendererHandle? _handle;
  String? _resolvedPath;
  File? _sessionFile;
  PdfRenderFailure? _failure;
  Timer? _markTimer;
  bool _loading = true;
  bool _chromeVisible = true;
  bool _vertical = true;
  bool _nightMode = false;
  int _quarterTurns = 0;
  int _page = 0;
  int _attempts = 0;
  int _materialised = 0;
  List<PdfPageGeometry> _geometry = const [];
  List<NormalizedRect> _highlights = const [];
  int? _highlightPage;

  @override
  void initState() {
    super.initState();
    _channel = ref.read(pdfRenderChannelProvider);
    // The first frame shows the loading state; the open starts right after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  @override
  void dispose() {
    _markTimer?.cancel();
    final handle = _handle;
    if (handle != null) unawaited(_channel.close(handle.id));
    final session = _sessionFile;
    if (session != null) {
      try {
        if (session.existsSync()) session.deleteSync();
      } on FileSystemException {
        // The startup sweep removes anything a failed delete leaves behind.
      }
    }
    super.dispose();
  }

  /// Opens (or re-opens with [password]) the resolved file.
  Future<void> _open({String? password}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final path = _resolvePath();
    if (path == null) {
      setState(() {
        _loading = false;
        _failure = PdfRenderFailure.corrupt;
      });
      return;
    }
    _resolvedPath = path;
    try {
      final handle = await _channel.open(path, password: password);
      if (!mounted) {
        unawaited(_channel.close(handle.id));
        return;
      }
      final entry = _entry;
      final lastPage = entry?.lastPage ?? 1;
      setState(() {
        _handle = handle;
        _loading = false;
        _failure = null;
        _page = lastPage.clamp(1, handle.pageCount) - 1;
        _geometry = [
          for (final page in handle.pages)
            PdfPageGeometry(
              widthPoints: page.widthPoints,
              heightPoints: page.heightPoints,
            ),
        ];
      });
      _scheduleMarkOpened();
    } on PdfRenderException catch (error) {
      if (!mounted) return;
      switch (error.failure) {
        case PdfRenderFailure.passwordRequired:
        case PdfRenderFailure.wrongPassword:
          setState(() => _loading = false);
          await _promptPassword(
            wrong: error.failure == PdfRenderFailure.wrongPassword,
          );
        default:
          setState(() {
            _loading = false;
            _failure = error.failure;
          });
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = PdfRenderFailure.unavailable;
      });
    }
  }

  /// Asks for the document password. Three failures stop the loop.
  Future<void> _promptPassword({required bool wrong}) async {
    if (_attempts >= 3) {
      setState(() => _failure = PdfRenderFailure.wrongPassword);
      return;
    }
    _attempts += 1;
    final password = await _askPassword(wrong: wrong);
    if (!mounted) return;
    if (password == null) {
      setState(() => _failure = PdfRenderFailure.passwordRequired);
      return;
    }
    await _open(password: password);
  }

  Future<String?> _askPassword({required bool wrong}) async {
    final field = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('الملف محمي بكلمة سر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              wrong
                  ? 'كلمة السر مش صح — جرّب تاني.'
                  : 'اكتب كلمة سر الملف عشان نعرضه على الجهاز.',
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: field,
              autofocus: true,
              obscureText: true,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.of(context).pop(value),
              decoration: const InputDecoration(hintText: 'كلمة السر'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: const TrText('فتح'),
          ),
        ],
      ),
    );
    field.dispose();
    return password;
  }

  /// Decides which file this reader should open.
  String? _resolvePath() {
    final docId = widget.docId;
    if (docId != null) {
      final file = ref.read(pdfLibraryStoreProvider).baseFile(docId);
      return file.existsSync() ? file.path : null;
    }
    if (widget.bytes != null) {
      final session = _sessionFile ??= _writeSessionFile(widget.bytes!);
      return session.path;
    }
    final path = widget.path;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// Materialises in-memory bytes for the native renderer.
  File _writeSessionFile(Uint8List bytes) {
    final store = ref.read(pdfLibraryStoreProvider);
    final noise = Random.secure().nextInt(1 << 24).toRadixString(16);
    final id =
        'session-${DateTime.now().microsecondsSinceEpoch}-${_materialised++}-$noise';
    final file = store.sessionTempFile(id);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes, flush: true);
    _sessionFile = file;
    return file;
  }

  PdfDocumentEntry? get _entry {
    final id = widget.docId;
    if (id == null) return null;
    for (final entry in ref.read(pdfLibraryControllerProvider).entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  void _scheduleMarkOpened() {
    final id = widget.docId;
    if (id == null) return;
    _markTimer?.cancel();
    _markTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref
          .read(pdfLibraryControllerProvider.notifier)
          .markOpened(id, page: _page + 1);
    });
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  Future<void> _toggleFavorite(PdfDocumentEntry entry) {
    return ref
        .read(pdfLibraryControllerProvider.notifier)
        .setFavorite(entry.id, !entry.favorite);
  }

  Future<void> _jumpToPage(int pageCount) async {
    final field = TextEditingController(text: '${_page + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('روح لصفحة'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (value) =>
              Navigator.of(context).pop(int.tryParse(value.trim())),
          decoration: InputDecoration(hintText: '1 — $pageCount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(field.text.trim())),
            child: const TrText('انتقال'),
          ),
        ],
      ),
    );
    field.dispose();
    if (target == null || !mounted) return;
    setState(() => _page = target.clamp(1, pageCount) - 1);
    _scheduleMarkOpened();
  }

  /// Opens in-document search over the resolved file.
  Future<void> _openSearch() async {
    final handle = _handle;
    final path = _resolvedPath;
    if (handle == null || path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final textMap = PdfTextMap.fromBytes(bytes, pageCount: handle.pageCount);
    await showPdfSearchSheet(
      context,
      textMap: textMap,
      onJump: (match) {
        Navigator.of(context).pop();
        _jumpToMatch(match);
      },
    );
  }

  void _jumpToMatch(PdfTextMatch match) {
    final count = _handle?.pageCount ?? 1;
    setState(() {
      _page = match.pageIndex.clamp(0, count - 1);
      _highlightPage = match.pageIndex;
      _highlights = [match.bounds];
    });
    _scheduleMarkOpened();
  }

  Future<void> _shareFile() async {
    final path = _resolvedPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final entry = _entry;
    await Share.shareXFiles(
      [XFile(path)],
      subject:
          entry?.displayName ??
          widget.title ??
          widget.fileName ??
          'zaker-document.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Favourite state lives in the library index; rebuild when it changes.
    ref.watch(pdfLibraryControllerProvider);
    final entry = _entry;
    final handle = _handle;
    final title =
        entry?.displayName ?? widget.title ?? widget.fileName ?? 'قارئ PDF';
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _body(context)),
          if (_chromeVisible && handle != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                title: title,
                favorite: entry?.favorite ?? false,
                canFavorite: entry != null,
                onBack: () => Navigator.of(context).maybePop(),
                onSearch: _openSearch,
                onFavorite: entry == null ? null : () => _toggleFavorite(entry),
              ),
            ),
          if (_chromeVisible && handle != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                page: _page + 1,
                pageCount: handle.pageCount,
                onJump: () => _jumpToPage(handle.pageCount),
                onScrub: (page) {
                  setState(() => _page = page - 1);
                  _scheduleMarkOpened();
                },
              ),
            ),
          if (_chromeVisible && handle != null)
            Positioned(
              right: ZakerSpacing.md,
              bottom: 88,
              child: _ReaderControls(
                vertical: _vertical,
                nightMode: _nightMode,
                onMode: () => setState(() => _vertical = !_vertical),
                onRotate: () =>
                    setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                onNight: () => setState(() => _nightMode = !_nightMode),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (_failure != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'تعذّر فتح الملف',
        message: _failureMessage,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () => _open(),
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('جرّب تاني'),
            ),
            if (_resolvedPath != null)
              TextButton.icon(
                onPressed: _shareFile,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const TrText('شارك الملف'),
              ),
          ],
        ),
      );
    }
    if (_loading || _handle == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: ZakerSpacing.md),
            TrText('بنفتح الملف…'),
          ],
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleChrome,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: PdfReaderViewport(
          handle: _handle!,
          geometry: _geometry,
          initialPage: _page,
          onPageChanged: (page) {
            if (page == _page) return;
            setState(() => _page = page);
            _scheduleMarkOpened();
          },
          vertical: _vertical,
          nightMode: _nightMode,
          quarterTurns: _quarterTurns,
          highlights: _highlights,
          highlightPage: _highlightPage,
        ),
      ),
    );
  }

  String get _failureMessage {
    return switch (_failure) {
      PdfRenderFailure.passwordRequired ||
      PdfRenderFailure.wrongPassword => 'الملف محمي بكلمة سر ومقدرناش نفتحه.',
      PdfRenderFailure.unavailable => 'قارئ PDF مش متاح على الجهاز ده.',
      _ => 'الملف تالف أو مش مقروء.',
    };
  }
}

/// Auto-hiding bar with the back button, the name and the favourite toggle.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.favorite,
    required this.canFavorite,
    required this.onBack,
    required this.onSearch,
    required this.onFavorite,
  });

  final String title;
  final bool favorite;
  final bool canFavorite;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'رجوع',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: TrText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'بحث جوه الملف',
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: favorite ? 'شيل من المفضلة' : 'ضيف للمفضلة',
              onPressed: canFavorite ? onFavorite : null,
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: favorite ? ZakerColors.accent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode, rotation and night-mode toggles floating above the bottom bar.
class _ReaderControls extends StatelessWidget {
  const _ReaderControls({
    required this.vertical,
    required this.nightMode,
    required this.onMode,
    required this.onRotate,
    required this.onNight,
  });

  final bool vertical;
  final bool nightMode;
  final VoidCallback onMode;
  final VoidCallback onRotate;
  final VoidCallback onNight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(ZakerRadius.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: vertical ? 'صفحة واحدة' : 'عرض مستمر',
            onPressed: onMode,
            icon: Icon(
              vertical
                  ? Icons.crop_portrait_rounded
                  : Icons.view_agenda_rounded,
            ),
          ),
          IconButton(
            tooltip: 'تدوير الصفحة',
            onPressed: onRotate,
            icon: const Icon(Icons.rotate_right_rounded),
          ),
          IconButton(
            tooltip: 'الوضع الليلي',
            onPressed: onNight,
            icon: Icon(
              nightMode ? Icons.dark_mode_rounded : Icons.dark_mode_outlined,
              color: nightMode ? ZakerColors.accent : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider, page counter and page jump.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.pageCount,
    required this.onJump,
    required this.onScrub,
  });

  final int page;
  final int pageCount;
  final VoidCallback onJump;
  final ValueChanged<int> onScrub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.sm,
            vertical: ZakerSpacing.xs,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: onJump,
                child: TrText('صفحة $page من $pageCount'),
              ),
              Expanded(
                child: Slider(
                  value: page.toDouble().clamp(1, pageCount.toDouble()),
                  min: 1,
                  max: pageCount < 2 ? 2 : pageCount.toDouble(),
                  divisions: pageCount < 2 ? 1 : pageCount - 1,
                  onChanged: (value) => onScrub(value.round()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
