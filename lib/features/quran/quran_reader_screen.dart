/// An in-app Quran reader with surah audio.
///
/// The text and the surah index come from the public AlQuran Cloud API
/// (`https://api.alquran.cloud/v1`), the same service family the original app
/// uses. Recitation audio is streamed from the Islamic Network CDN with the
/// device's player, so no extra audio package is needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/quran_data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../hifz/hifz_setup_screen.dart';

/// The Quran reader: the surah index and a reader for each surah.
class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key, this.initialSurahNumber});

  /// Opens this surah immediately after the index loads.  Used by the Friday
  /// Kahf reminder; the normal reader flow leaves this null.
  final int? initialSurahNumber;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  List<QuranSurah> _surahs = const [];
  Object? _error;
  bool _loading = true;
  String _query = '';
  bool _openedInitialSurah = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = _surahs.isEmpty;
      _error = null;
    });
    try {
      final surahs = await ref.read(quranDataProvider).surahs(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _loading = false;
      });
      _maybeOpenInitialSurah(surahs);
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
        .where((s) {
          return s.name.contains(query) ||
              '${s.number}'.contains(query) ||
              s.englishName.toLowerCase().contains(query.toLowerCase());
        })
        .toList(growable: false);
  }

  void _open(QuranSurah surah) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _SurahScreen(surah: surah)));
  }

  /// Pushes the requested surah once, after the index has loaded.
  void _maybeOpenInitialSurah(List<QuranSurah> surahs) {
    final target = widget.initialSurahNumber;
    if (target == null || _openedInitialSurah) return;
    for (final surah in surahs) {
      if (surah.number != target) continue;
      _openedInitialSurah = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(surah);
      });
      return;
    }
  }

  Future<void> _listen(QuranSurah surah) async {
    final uri = Uri.parse('$kQuranAudioBase/${surah.number}.mp3');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('مش قادر أفتح مشغل الصوت.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('مش قادر أفتح مشغل الصوت.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const TrText('المصحف')),
      body: _loading
          ? const LoadingBox()
          : _error != null
          ? _ErrorState(
              message: 'مش قادر أوصل لسيرفر المصحف دلوقتي. اتأكد من النت وجرّب تاني.',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      ZakerSpacing.lg,
                      ZakerSpacing.lg,
                      ZakerSpacing.lg,
                      ZakerSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ReaderHeader(),
                          const SizedBox(height: ZakerSpacing.md),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: const InputDecoration(
                              hintText: 'دوّر على سورة…',
                              prefixIcon: Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'مفيش سورة بالاسم ده',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        ZakerSpacing.lg,
                        0,
                        ZakerSpacing.lg,
                        ZakerSpacing.xl,
                      ),
                      sliver: SliverList.separated(
                        itemCount: _visible.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: ZakerSpacing.sm),
                        itemBuilder: (context, index) {
                          final surah = _visible[index];
                          return _SurahTile(
                            surah: surah,
                            onOpen: () => _open(surah),
                            onListen: () => _listen(surah),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// The gradient header above the surah list.
class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [theme.colorScheme.primary, ZakerColors.primaryDark],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ZakerRadius.md),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: ZakerSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'القرآن الكريم',
                  style: TextStyle(
                    fontFamily: ZakerTheme.fontQuran,
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                TrText(
                  '١١٤ سورة — اقرا واستمع بصوت مشاري العفاسي',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the surah index.
class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.onOpen,
    required this.onListen,
  });

  final QuranSurah surah;
  final VoidCallback onOpen;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ZakerSpacing.md,
            ZakerSpacing.sm,
            ZakerSpacing.sm,
            ZakerSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
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
              IconButton(
                tooltip: 'استمع',
                onPressed: onListen,
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  color: theme.colorScheme.primary,
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

/// The reader for a single surah.
class _SurahScreen extends ConsumerStatefulWidget {
  const _SurahScreen({required this.surah});

  final QuranSurah surah;

  @override
  ConsumerState<_SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends ConsumerState<_SurahScreen> {
  List<String>? _ayahs;
  Object? _error;
  bool _loading = true;

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
      final ayahs = await ref
          .read(quranDataProvider)
          .ayahsFor(widget.surah.number);
      if (!mounted) return;
      setState(() {
        _ayahs = ayahs;
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

  Future<void> _listen() async {
    final uri = Uri.parse('$kQuranAudioBase/${widget.surah.number}.mp3');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TrText('مش قادر أفتح مشغل الصوت.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('مش قادر أفتح مشغل الصوت.')),
      );
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: TrText('اتنسخت الآية ✅')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TrText(
          widget.surah.name,
          style: const TextStyle(
            fontFamily: ZakerTheme.fontQuran,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'احفظ السورة',
            icon: const Icon(Icons.psychology_alt_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    HifzSetupScreen(initialSurahNumber: widget.surah.number),
              ),
            ),
          ),
          IconButton(
            tooltip: 'استمع للسورة',
            icon: const Icon(Icons.headphones_rounded),
            onPressed: _listen,
          ),
        ],
      ),
      body: _loading
          ? const LoadingBox()
          : _error != null
          ? _ErrorState(
              message: 'مش قادر أجيب نص السورة دلوقتي. جرّب تاني.',
              onRetry: _load,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              itemCount: (_ayahs?.length ?? 0) + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(ZakerSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: ZakerRadius.card,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: ZakerSpacing.sm),
                          Expanded(
                            child: TrText(
                              '${widget.surah.revelation} · '
                              '${widget.surah.ayahCount} آية · '
                              'اضغط مطوّل على الآية تنسخها',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final ayah = _ayahs![index - 1];
                return GestureDetector(
                  onLongPress: () => _copy(ayah),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
                    padding: const EdgeInsets.all(ZakerSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: ZakerRadius.card,
                      border: Border.all(
                        color: theme.dividerTheme.color ?? Colors.black12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TrText(
                          ayah,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: ZakerTheme.fontQuran,
                            fontSize: 22,
                            height: 2.0,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: ZakerSpacing.xs),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: TrText(
                              '${index}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A retryable network error.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
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
            TrText(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
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
