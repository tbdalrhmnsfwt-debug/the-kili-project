/// In-document search for the native reader.
///
/// [PdfSearchSheet] is the sheet body; open it with [showPdfSearchSheet] so it
/// sits inside a draggable modal. Typed text never leaves the device and is
/// never logged.
library;

import 'package:flutter/material.dart';

import '../../../core/pdf/pdf_text_map.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// Opens the search sheet and calls [onJump] when the user picks a hit.
Future<void> showPdfSearchSheet(
  BuildContext context, {
  required PdfTextMap textMap,
  required ValueChanged<PdfTextMatch> onJump,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => PdfSearchSheet(
        textMap: textMap,
        onJump: onJump,
        scrollController: scrollController,
      ),
    ),
  );
}

/// Search field, progress line, result rows and the empty states.
class PdfSearchSheet extends StatefulWidget {
  const PdfSearchSheet({
    super.key,
    required this.textMap,
    required this.onJump,
    this.scrollController,
  });

  final PdfTextMap textMap;
  final ValueChanged<PdfTextMatch> onJump;

  /// Supplied by [DraggableScrollableSheet]; the sheet works without it.
  final ScrollController? scrollController;

  @override
  State<PdfSearchSheet> createState() => _PdfSearchSheetState();
}

class _PdfSearchSheetState extends State<PdfSearchSheet> {
  final TextEditingController _query = TextEditingController();
  bool? _hasText;
  bool _searching = false;
  List<PdfTextMatch> _matches = const [];
  String _searched = '';
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _checkText();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _checkText() async {
    final hasText = await widget.textMap.hasAnyText();
    if (!mounted) return;
    setState(() => _hasText = hasText);
  }

  Future<void> _run() async {
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _matches = const [];
        _searched = '';
        _searching = false;
      });
      return;
    }
    final serial = ++_serial;
    setState(() {
      _searching = true;
      _searched = query;
      _matches = const [];
    });
    final matches = await widget.textMap.search(query);
    if (!mounted || serial != _serial) return;
    setState(() {
      _matches = matches;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.md,
            ZakerSpacing.sm,
            ZakerSpacing.md,
            ZakerSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(),
                  decoration: const InputDecoration(
                    hintText: 'دوّر جوه الملف',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              FilledButton(
                onPressed: _searching ? null : _run,
                child: const TrText('بحث'),
              ),
            ],
          ),
        ),
        if (_searching) const LinearProgressIndicator(),
        Expanded(child: _results(context, _hasText, theme)),
      ],
    );
  }

  Widget _results(BuildContext context, bool? hasText, ThemeData theme) {
    if (hasText == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          child: TrText(
            'الملف ده صور — مفيش نص نبحث فيه',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (_searching) {
      return const Center(child: TrText('بندوّر…'));
    }
    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          child: TrText(
            _searched.isEmpty
                ? 'اكتب كلمة وابدأ البحث'
                : 'مفيش نتايج حوالين «$_searched»',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      itemCount: _matches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final match = _matches[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            child: TrText(
              '${match.pageIndex + 1}',
              style: theme.textTheme.labelSmall,
            ),
          ),
          title: Text(
            match.snippet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: TrText('صفحة ${match.pageIndex + 1}'),
          onTap: () => widget.onJump(match),
        );
      },
    );
  }
}
