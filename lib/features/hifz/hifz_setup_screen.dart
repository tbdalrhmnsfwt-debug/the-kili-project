/// Starts a new memorization session: pick a surah, an ayah range and a
/// hiding mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/quran_data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'hifz_models.dart';
import 'hifz_session_screen.dart';
import 'hifz_style.dart';

/// Lets the student choose what to recite from the Quran data the reader uses.
class HifzSetupScreen extends ConsumerStatefulWidget {
  const HifzSetupScreen({super.key, this.initialSurahNumber});

  /// Preselects a surah, used when a part is started from the reader.
  final int? initialSurahNumber;

  @override
  ConsumerState<HifzSetupScreen> createState() => _HifzSetupScreenState();
}

class _HifzSetupScreenState extends ConsumerState<HifzSetupScreen> {
  List<QuranSurah> _surahs = const [];
  Object? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _surahs.isEmpty;
      _error = null;
    });
    try {
      final surahs = await ref.read(quranDataProvider).surahs();
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<QuranSurah> get _visible {
    final query = _query.trim();
    if (query.isEmpty) return _surahs;
    return _surahs
        .where((surah) {
          return surah.name.contains(query) ||
              '${surah.number}'.contains(query) ||
              surah.englishName.toLowerCase().contains(query.toLowerCase());
        })
        .toList(growable: false);
  }

  Future<void> _configure(QuranSurah surah) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RangeSheet(
        surah: surah,
        onStart: (range, mode) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HifzSessionScreen(
                surahNumber: surah.number,
                surahName: surah.name,
                startAyah: range.start,
                endAyah: range.end,
                mode: mode,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const TrText('حفظ جديد')),
      body: _loading
          ? const LoadingBox(label: 'بنجيب السور…')
          : _error != null
          ? _SetupError(onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                ZakerSpacing.sm,
                ZakerSpacing.lg,
                ZakerSpacing.xxl,
              ),
              children: [
                const TrText(
                  'اختار السورة اللي عايز تحفظها، وحدد الآيات وطريقة الإخفاء.',
                  style: TextStyle(fontSize: 12.5, height: 1.6),
                ),
                const SizedBox(height: ZakerSpacing.md),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'دوّر على سورة…',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.md),
                if (_visible.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'مفيش سورة بالاسم ده',
                  )
                else
                  for (final surah in _visible)
                    _SurahRow(
                      surah: surah,
                      highlighted: surah.number == widget.initialSurahNumber,
                      onTap: () => _configure(surah),
                    ),
              ],
            ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.surah,
    required this.highlighted,
    required this.onTap,
  });

  final QuranSurah surah;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.55)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ZakerRadius.card,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ZakerSpacing.md,
              ZakerSpacing.sm,
              ZakerSpacing.sm,
              ZakerSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: TrText(
                    '${surah.number}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        surah.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: ZakerTheme.fontQuran,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TrText(
                        '${surah.revelation} · ${surah.ayahCount} آية',
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
      ),
    );
  }
}

/// Ayah range and hiding mode for one surah.
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({required this.surah, required this.onStart});

  final QuranSurah surah;
  final void Function(({int start, int end}) range, HifzHideMode mode) onStart;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late RangeValues _range = RangeValues(1, widget.surah.ayahCount.toDouble());
  HifzHideMode _mode = HifzHideMode.lastWords;

  int get _start => _range.start.round();

  int get _end => _range.end.round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAyah = widget.surah.ayahCount.toDouble();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
          ZakerSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TrText(
                    widget.surah.name,
                    style: const TextStyle(
                      fontFamily: ZakerTheme.fontQuran,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TrText(
                  '${widget.surah.ayahCount} آية',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.lg),
            SectionHeader(
              title: 'الآيات: $_start–$_end',
              icon: Icons.format_list_numbered_rounded,
            ),
            RangeSlider(
              values: _range,
              min: 1,
              max: maxAyah,
              divisions: widget.surah.ayahCount - 1,
              labels: RangeLabels('$_start', '$_end'),
              onChanged: (values) {
                setState(
                  () => _range = RangeValues(
                    values.start.roundToDouble(),
                    values.end.roundToDouble(),
                  ),
                );
              },
            ),
            const SizedBox(height: ZakerSpacing.sm),
            const SectionHeader(
              title: 'طريقة الإخفاء',
              icon: Icons.visibility_off_rounded,
            ),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.sm,
              children: [
                for (final mode in HifzHideMode.values)
                  ChoiceChip(
                    label: TrText(mode.label),
                    avatar: Icon(
                      mode.icon,
                      size: 16,
                      color: _mode == mode
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    selected: _mode == mode,
                    onSelected: (_) => setState(() => _mode = mode),
                  ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              _mode.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xl),
            FilledButton.icon(
              onPressed: () =>
                  widget.onStart((start: _start, end: _end), _mode),
              icon: const Icon(Icons.play_arrow_rounded),
              label: TrText('ابدأ تسميع ${_end - _start + 1} آية'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: ZakerSpacing.md),
            const TrText(
              'مش قادر أجيب قائمة السور دلوقتي. اتأكد من النت وجرّب تاني.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZakerSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('جرّب تاني'),
            ),
          ],
        ),
      ),
    );
  }
}
