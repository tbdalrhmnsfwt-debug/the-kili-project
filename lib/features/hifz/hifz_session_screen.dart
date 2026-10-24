/// A memorization session: recite the chosen ayahs with words hidden, mark each
/// ayah yourself, then see the score and the next review date.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/quran_data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'hifz_engine.dart';
import 'hifz_models.dart';
import 'hifz_providers.dart';
import 'hifz_style.dart';

/// Strong enough colours for text on light and dark surfaces (WCAG AA).
const Color _okLight = Color(0xFF166534);
const Color _okDark = Color(0xFF4ADE80);
const Color _reviewLight = Color(0xFFB45309);
const Color _reviewDark = Color(0xFFFBBF24);

Color _okColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? _okDark : _okLight;

Color _reviewColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? _reviewDark
    : _reviewLight;

/// One self-checked recitation of an ayah range.
class HifzSessionScreen extends ConsumerStatefulWidget {
  const HifzSessionScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.startAyah,
    required this.endAyah,
    required this.mode,
    this.partId,
  });

  final int surahNumber;
  final String surahName;
  final int startAyah;
  final int endAyah;
  final HifzHideMode mode;

  /// The saved part being reviewed; null for a brand-new memorization.
  final String? partId;

  @override
  ConsumerState<HifzSessionScreen> createState() => _HifzSessionScreenState();
}

class _HifzSessionScreenState extends ConsumerState<HifzSessionScreen> {
  List<String>? _ayahs;
  Object? _error;
  bool _loading = true;
  int _startAyah = 1;
  int _endAyah = 1;

  /// ayah number → true (correct) / false (needs review).
  final Map<int, bool> _marks = {};
  final Map<int, Set<int>> _revealedWords = {};
  final Set<int> _revealedAyahs = {};
  bool _revealAll = false;

  bool _finished = false;
  HifzSessionResult? _result;
  HifzPart? _savedPart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _ayahs == null;
      _error = null;
    });
    try {
      final all = await ref
          .read(quranDataProvider)
          .ayahsFor(widget.surahNumber);
      if (!mounted) return;
      if (all.isEmpty) {
        setState(() {
          _error = StateError('empty surah');
          _loading = false;
        });
        return;
      }
      final start = widget.startAyah.clamp(1, all.length);
      final end = widget.endAyah.clamp(start, all.length);
      setState(() {
        _startAyah = start;
        _endAyah = end;
        _ayahs = all.sublist(start - 1, end);
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

  int get _total => _ayahs?.length ?? 0;

  /// Only the ayahs marked so far, in order — what the live score reflects.
  HifzSessionResult get _liveResult {
    final marks = <HifzAyahMark>[];
    for (var i = 0; i < _total; i++) {
      final number = _startAyah + i;
      final mark = _marks[number];
      if (mark == null) continue;
      marks.add(HifzAyahMark(ayahNumber: number, correct: mark));
    }
    return HifzSessionResult(marks: marks);
  }

  HifzSessionResult get _finalResult {
    return HifzSessionResult(
      marks: [
        for (var i = 0; i < _total; i++)
          HifzAyahMark(
            ayahNumber: _startAyah + i,
            correct: _marks[_startAyah + i] == true,
          ),
      ],
    );
  }

  void _mark(int ayahNumber, bool correct) {
    setState(() => _marks[ayahNumber] = correct);
  }

  void _revealWord(int ayahNumber, int index) {
    setState(() {
      (_revealedWords[ayahNumber] ??= <int>{}).add(index);
    });
  }

  void _revealAyah(int ayahNumber) {
    setState(() => _revealedAyahs.add(ayahNumber));
  }

  void _finish() {
    if (_finished || _marks.length < _total) return;
    final result = _finalResult;
    final now = DateTime.now();
    final controller = ref.read(hifzProvider.notifier);
    late final String partId;
    if (widget.partId == null) {
      partId = newHifzPartId(widget.surahNumber, _startAyah, _endAyah, now);
      controller.savePart(
        HifzPart(
          id: partId,
          surahNumber: widget.surahNumber,
          surahName: widget.surahName,
          startAyah: _startAyah,
          endAyah: _endAyah,
          hideMode: widget.mode,
          createdAt: now,
        ),
      );
      controller.recordSession(partId, result, now: now, firstSession: true);
    } else {
      partId = widget.partId!;
      controller.recordSession(partId, result, now: now);
    }
    HifzPart? saved;
    for (final part in ref.read(hifzProvider).parts) {
      if (part.id == partId) saved = part;
    }
    setState(() {
      _finished = true;
      _result = result;
      _savedPart = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMarked = _total > 0 && _marks.length >= _total;
    return Scaffold(
      appBar: AppBar(
        title: const TrText('تسميع'),
        actions: [
          if (!_finished && _ayahs != null)
            IconButton(
              tooltip: _revealAll ? 'اخفي الكلمات تاني' : 'اكشف كل الكلمات',
              onPressed: () => setState(() => _revealAll = !_revealAll),
              icon: Icon(
                _revealAll
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
            ),
        ],
      ),
      body: _loading
          ? const LoadingBox(label: 'بنجيب الآيات…')
          : _error != null
          ? _SessionError(onRetry: _load)
          : _finished
          ? _SummaryBody(
              surahName: widget.surahName,
              startAyah: _startAyah,
              endAyah: _endAyah,
              result: _result!,
              part: _savedPart,
              streakDays: ref.watch(hifzProvider).streakDays,
              onDone: () => Navigator.of(context).pop(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                ZakerSpacing.sm,
                ZakerSpacing.lg,
                ZakerSpacing.xl,
              ),
              children: [
                _SessionHeader(
                  surahName: widget.surahName,
                  startAyah: _startAyah,
                  endAyah: _endAyah,
                  mode: widget.mode,
                  live: _liveResult,
                  marked: _marks.length,
                  total: _total,
                ),
                const SizedBox(height: ZakerSpacing.md),
                if (widget.mode != HifzHideMode.none && !_revealAll)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
                    child: TrText(
                      'اقرا الآية من حفظك، واضغط على الكلمة المخفية لو احتجت تفتكرها. '
                      'بعد ما تخلص كل آية علّمها: صح ولا محتاجة مراجعة.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ),
                for (var i = 0; i < _total; i++)
                  _AyahCard(
                    key: ValueKey('hifz-ayah-${_startAyah + i}'),
                    ayahNumber: _startAyah + i,
                    text: _ayahs![i],
                    mode: widget.mode,
                    mark: _marks[_startAyah + i],
                    revealAll: _revealAll,
                    revealedWords:
                        _revealedWords[_startAyah + i] ?? const <int>{},
                    ayahRevealed: _revealedAyahs.contains(_startAyah + i),
                    onRevealWord: (index) => _revealWord(_startAyah + i, index),
                    onRevealAyah: () => _revealAyah(_startAyah + i),
                    onMark: (correct) => _mark(_startAyah + i, correct),
                  ),
              ],
            ),
      bottomNavigationBar: _loading || _error != null || _finished
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                ZakerSpacing.sm,
                ZakerSpacing.lg,
                ZakerSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!allMarked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: TrText(
                        'فاضل ${_total - _marks.length} آية تعلّمها',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: allMarked ? _finish : null,
                      icon: const Icon(Icons.flag_rounded),
                      label: const TrText('خلّص الجلسة'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The gradient strip above the ayah cards.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.surahName,
    required this.startAyah,
    required this.endAyah,
    required this.mode,
    required this.live,
    required this.marked,
    required this.total,
  });

  final String surahName;
  final int startAyah;
  final int endAyah;
  final HifzHideMode mode;
  final HifzSessionResult live;
  final int marked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final score = live.total == 0 ? null : (live.score * 100).round();
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF0D4F4A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded, color: Colors.white),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: TrText(
                  surahName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: ZakerTheme.fontQuran,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TrText(
            'الآيات $startAyah–$endAyah · ${mode.label}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : marked / total,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              TrText(
                '$marked / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              _HeaderChip(
                icon: Icons.percent_rounded,
                label: score == null ? 'النتيجة: —' : 'النتيجة: $score%',
              ),
              _HeaderChip(
                icon: Icons.local_fire_department_rounded,
                label: 'تتابعك: ${live.bestStreak}',
              ),
              _HeaderChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'صح: ${live.correct}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          TrText(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One ayah with its word-level masking and the two self-check buttons.
class _AyahCard extends StatelessWidget {
  const _AyahCard({
    super.key,
    required this.ayahNumber,
    required this.text,
    required this.mode,
    required this.mark,
    required this.revealAll,
    required this.revealedWords,
    required this.ayahRevealed,
    required this.onRevealWord,
    required this.onRevealAyah,
    required this.onMark,
  });

  final int ayahNumber;
  final String text;
  final HifzHideMode mode;
  final bool? mark;
  final bool revealAll;
  final Set<int> revealedWords;
  final bool ayahRevealed;
  final ValueChanged<int> onRevealWord;
  final VoidCallback onRevealAyah;
  final ValueChanged<bool> onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mask = hifzAyahMask(text, mode: mode, seed: ayahNumber);
    final fullyRevealed = revealAll || ayahRevealed || mask.hidden.isEmpty;
    final anyHidden = !fullyRevealed;
    final borderColor = mark == null
        ? theme.dividerTheme.color ?? Colors.black12
        : (mark! ? _okColor(context) : _reviewColor(context)).withValues(
            alpha: 0.55,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(ZakerRadius.pill),
                ),
                child: TrText(
                  '$ayahNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (anyHidden)
                TextButton.icon(
                  onPressed: onRevealAyah,
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const TrText('اكشف الآية'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                )
              else if (mode != HifzHideMode.none)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TrText(
                    'مكشوفة',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < mask.words.length; i++)
                _WordChip(
                  word: mask.words[i],
                  hidden:
                      !fullyRevealed &&
                      mask.hidden.contains(i) &&
                      !revealedWords.contains(i),
                  onTap: () => onRevealWord(i),
                  dark: isDark,
                ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: _VerdictButton(
                  label: 'سمّعتها صح',
                  icon: Icons.check_rounded,
                  color: _okColor(context),
                  selected: mark == true,
                  onPressed: () => onMark(true),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: _VerdictButton(
                  label: 'محتاجة مراجعة',
                  icon: Icons.replay_rounded,
                  color: _reviewColor(context),
                  selected: mark == false,
                  onPressed: () => onMark(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.hidden,
    required this.onTap,
    required this.dark,
  });

  final String word;
  final bool hidden;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (hidden) {
      return Semantics(
        button: true,
        label: 'كلمة مخفية، اضغط للكشف',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZakerRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minWidth: 38),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: dark ? 0.26 : 0.12,
              ),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '•••',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: dark ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
      ),
      child: Text(
        word,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: ZakerTheme.fontQuran,
          fontSize: 21,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: TrText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: selected ? 0.18 : 0.06),
        side: BorderSide(
          color: color.withValues(alpha: selected ? 0.85 : 0.35),
          width: selected ? 1.4 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
        ),
      ),
    );
  }
}

/// The score after the last ayah is marked, before returning to the list.
class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.surahName,
    required this.startAyah,
    required this.endAyah,
    required this.result,
    required this.part,
    required this.streakDays,
    required this.onDone,
  });

  final String surahName;
  final int startAyah;
  final int endAyah;
  final HifzSessionResult result;
  final HifzPart? part;
  final int streakDays;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (result.score * 100).round();
    final now = DateTime.now();
    final headline = result.perfect
        ? 'تسميع متقن، ما شاء الله'
        : 'خلّصت الجلسة — كمّل تثبيت';
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.xl,
        ZakerSpacing.lg,
        ZakerSpacing.xl,
      ),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_okColor(context)).withValues(alpha: 0.12),
              border: Border.all(
                color: _okColor(context).withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: Icon(
              result.perfect ? Icons.workspace_premium_rounded : Icons.school,
              size: 46,
              color: _okColor(context),
            ),
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        TrText(
          headline,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        TrText(
          '$surahName · الآيات $startAyah–$endAyah',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.xl),
        Container(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  TrText(
                    'النتيجة',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TrText(
                    '$percent%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: percent >= 80
                          ? _okColor(context)
                          : _reviewColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.sm),
              ProgressBar(
                value: result.score,
                height: 8,
                color: percent >= 80
                    ? _okColor(context)
                    : _reviewColor(context),
              ),
              const SizedBox(height: ZakerSpacing.md),
              Wrap(
                spacing: ZakerSpacing.sm,
                runSpacing: ZakerSpacing.sm,
                children: [
                  StatChip(
                    icon: Icons.check_circle_outline_rounded,
                    value: '${result.correct}',
                    label: 'آية صح',
                    color: _okColor(context),
                  ),
                  StatChip(
                    icon: Icons.replay_rounded,
                    value: '${result.needsReview}',
                    label: 'محتاجة مراجعة',
                    color: _reviewColor(context),
                  ),
                  StatChip(
                    icon: Icons.local_fire_department_rounded,
                    value: '${result.bestStreak}',
                    label: 'أفضل تتابع',
                    color: _okColor(context),
                  ),
                  StatChip(
                    icon: Icons.calendar_month_rounded,
                    value: '$streakDays',
                    label: 'يوم متواصل',
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        if (part != null)
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: ZakerRadius.card,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        hifzDueLabel(part!, now),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TrText(
                        'الجدول: مراجعة بعد يوم، ٣ أيام، أسبوع، وبعدها كل أسبوعين.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: ZakerSpacing.xl),
        FilledButton.icon(
          onPressed: onDone,
          icon: const Icon(Icons.done_all_rounded),
          label: const TrText('رجوع للمحفوظات'),
        ),
      ],
    );
  }
}

class _SessionError extends StatelessWidget {
  const _SessionError({required this.onRetry});

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
              'مش قادر أجيب آيات السورة دلوقتي. اتأكد من النت وجرّب تاني.',
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
