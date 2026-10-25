/// Plays one private batch audio resource with resume and an honest
/// transcription-blocked card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/audio_playback_controller.dart';
import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_resource_paths.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/theme.dart';
import '../../../models/batch_resource.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../../../widgets/zaker_visuals.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';

class AudioResourceScreen extends ConsumerWidget {
  const AudioResourceScreen({
    super.key,
    required this.batchId,
    required this.resourceId,
  });

  final String batchId;
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const TrText('الملف الصوتي')),
        body: const Center(child: LoadingBox(label: 'بنفتح الملف…')),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const TrText('الملف الصوتي')),
        body: _AudioError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
      ),
      data: (snapshot) {
        BatchResource? resource;
        for (final item in snapshot.resources) {
          if (item.id == resourceId) {
            resource = item;
            break;
          }
        }
        if (resource == null) {
          return Scaffold(
            appBar: AppBar(title: const TrText('الملف الصوتي')),
            body: const EmptyState(
              icon: Icons.graphic_eq_rounded,
              title: 'الملف مش موجود',
              message: 'يمكن الملف اتمسح من الدفعة.',
            ),
          );
        }
        final path = BatchResourcePaths.filePath(resource);
        if (path == null) {
          return Scaffold(
            appBar: AppBar(title: const TrText('الملف الصوتي')),
            body: const EmptyState(
              icon: Icons.insert_drive_file_outlined,
              title: 'الملف مش متاح',
              message: 'مش عارفين نلاقي نسخة محفوظة من الملف ده.',
            ),
          );
        }
        final uid = ref.watch(authUserProvider)?.uid ?? '';
        final missing = ref
                .watch(
                  resourceMissingProvider(
                    (batchId: batchId, relativePath: path),
                  ),
                )
                .valueOrNull ??
            false;
        if (missing) {
          return Scaffold(
            appBar: AppBar(title: TrText(resource.title)),
            body: const EmptyState(
              icon: Icons.link_off_rounded,
              title: 'الملف مش موجود على الجهاز',
              message: 'النسخة الخاصة بالملف اتشالت من جهازك. '
                  'مفيش نسخة على سيرفر نجيبها.',
            ),
          );
        }
        final absolute = ref
            .watch(batchFileStoreProvider)
            .fileInBatch(uid, batchId, path)
            .path;
        final subjectName = _subjectName(snapshot, resource.subjectId);
        return _PlayerScreen(
          key: ValueKey('${resource.id}:$absolute'),
          batchId: batchId,
          resource: resource,
          absolutePath: absolute,
          subjectName: subjectName,
        );
      },
    );
  }

  static String _subjectName(BatchSnapshot snapshot, String subjectId) {
    for (final subject in snapshot.batch.subjects) {
      if (subject.id == subjectId) return subject.name;
    }
    return '';
  }
}

class _PlayerScreen extends ConsumerStatefulWidget {
  const _PlayerScreen({
    super.key,
    required this.batchId,
    required this.resource,
    required this.absolutePath,
    required this.subjectName,
  });

  final String batchId;
  final BatchResource resource;
  final String absolutePath;
  final String subjectName;

  @override
  ConsumerState<_PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<_PlayerScreen>
    with WidgetsBindingObserver {
  late AudioPlaybackController _controller;
  int? _dragMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _create();
    _controller.initialize();
  }

  AudioPlaybackController _create() {
    return AudioPlaybackController(
      bindings: ref.read(audioPlayerBindingsProvider),
      positions: ref.read(playbackPositionStoreProvider),
      uid: ref.read(authUserProvider)?.uid ?? '',
      batchId: widget.batchId,
      resourceId: widget.resource.id,
      path: widget.absolutePath,
      knownDurationMs: widget.resource.durationMs,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final previous = _controller;
    previous.dispose();
    try {
      // Release the native player before opening the file again: a late
      // release would tear down the player the retry just created.
      await previous.close();
    } on Object {
      // A failed close must not block the retry.
    }
    if (!mounted) return;
    setState(() {
      _dragMs = null;
      _controller = _create();
      _controller.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: TrText(widget.resource.title)),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _Header(
            resource: widget.resource,
            subjectName: widget.subjectName,
          ),
          const SizedBox(height: ZakerSpacing.lg),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _PlayerCard(
              controller: _controller,
              dragMs: _dragMs,
              onDrag: (value) => setState(() => _dragMs = value.round()),
              onSeek: (value) {
                setState(() => _dragMs = null);
                _controller.seekTo(value.round());
              },
              onRetry: _retry,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          const _LocalOnlyNote(),
          const SizedBox(height: ZakerSpacing.lg),
          const _TranscriptionCard(),
          const SizedBox(height: ZakerSpacing.lg),
          Text(
            'الملف بيتشغل من النسخة المحفوظة على جهازك. '
            'مفيش رابط عام للملف ومفيش رفع لمخزن سحابي.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.resource, required this.subjectName});

  final BatchResource resource;
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = <String>[
      if (subjectName.isNotEmpty) subjectName,
      if (resource.durationMs != null) formatDuration(resource.durationMs!),
      formatBytes(resource.sizeBytes),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZakerGlassGlyph(
          icon: Icons.graphic_eq_rounded,
          accent: theme.colorScheme.primary,
          size: 54,
          iconSize: 26,
          radius: ZakerRadius.sm,
        ),
        const SizedBox(width: ZakerSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                resource.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              TrText(
                meta.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.controller,
    required this.dragMs,
    required this.onDrag,
    required this.onSeek,
    required this.onRetry,
  });

  final AudioPlaybackController controller;
  final int? dragMs;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onSeek;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = controller.durationMs;
    final ready = controller.isReady;
    final position = (dragMs ?? controller.positionMs)
        .clamp(0, duration > 0 ? duration : 0)
        .toInt();
    final failed = controller.hasError;

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: failed
              ? theme.colorScheme.error.withValues(alpha: 0.35)
              : theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          if (failed) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: TrText(
                    _errorText(controller.errorCode),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const TrText('جرّب تاني'),
              ),
            ),
          ] else ...[
            if (!ready)
              Padding(
                padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    Expanded(
                      child: TrText(
                        'بنجهز الملف…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Slider(
              value: duration > 0 ? position.toDouble() : 0,
              max: duration > 0 ? duration.toDouble() : 1,
              onChanged: ready ? onDrag : null,
              onChangeEnd: ready ? onSeek : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZakerSpacing.xs,
              ),
              child: Row(
                children: [
                  Text(
                    formatDuration(position),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TrText(
                    duration > 0
                        ? formatDuration(duration)
                        : 'المدة لسه مش معروفة',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'ارجع ١٠ ثواني',
                  onPressed: ready
                      ? () => controller.seekTo(controller.positionMs - 10000)
                      : null,
                  icon: const Icon(Icons.replay_10_rounded, size: 30),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Semantics(
                  button: true,
                  label: controller.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                  child: FilledButton(
                    onPressed: ready ? controller.toggle : null,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(ZakerSpacing.md),
                    ),
                    child: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                IconButton(
                  tooltip: 'قدّم ١٠ ثواني',
                  onPressed: ready
                      ? () => controller.seekTo(controller.positionMs + 10000)
                      : null,
                  icon: const Icon(Icons.forward_10_rounded, size: 30),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _errorText(String? code) => switch (code) {
        'openFailed' => 'الملف الصوتي مش مقروء. يمكن الملف اتلف أو اتشال.',
        'focusDenied' => 'مقدرناش ناخد الصوت من تطبيق تاني. جرّب تاني.',
        'playbackFailed' => 'التشغيل وقف بسبب مشكلة في الملف.',
        'notReady' => 'الملف لسه بيتجهز.',
        'unavailable' => 'مشغّل الصوت مش متاح في النسخة دي من التطبيق.',
        _ => 'حصل خطأ وإحنا بنشغل الملف.',
      };
}

class _LocalOnlyNote extends StatelessWidget {
  const _LocalOnlyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.phonelink_lock_rounded,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TrText(
            'التشغيل بيتم من الملف المحفوظ على الجهاز، والموضع بيتحفظ '
            'لما ترجع تفتحه.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptionCard extends StatelessWidget {
  const _TranscriptionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.subtitles_off_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              const Expanded(
                child: TrText(
                  'تفريغ الصوت',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'التفريغ الآلي مش متاح في النسخة دي. مفيش موديل تفريغ على '
            'الجهاز، ومفيش مزوّد خارجي متظبط، فمفيش حاجة بتترفع لأي مكان.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _showExplanation(context),
              child: const TrText('إزاي بيشتغل التفريغ؟'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExplanation(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            0,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TrText(
                'ليه مفيش تفريغ؟',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              const _ExplanationLine(
                icon: Icons.memory_rounded,
                text: 'التفريغ على الجهاز محتاج موديل تعرّف صوت عربي محمّل '
                    'مع التطبيق. الموديل ده مش موجود في النسخة الحالية، '
                    'فمفيش تفريغ محلي.',
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const _ExplanationLine(
                icon: Icons.cloud_off_rounded,
                text: 'التفريغ السحابي محتاج موافقة صريحة منك ومفتاح مزوّد '
                    'محفوظ في سيرفر. مفيش سيرفر ولا مزوّد متظبط، ومفيش صوت '
                    'بيتبعت بره الجهاز.',
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const _ExplanationLine(
                icon: Icons.text_snippet_outlined,
                text: 'مفيش نصوص أو مقاطع محفوظة بشكل وهمي. لو اتضاف مزوّد '
                    'بعدين، التفريغ هيظهر هنا بنصه الحقيقي.',
              ),
              const SizedBox(height: ZakerSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const TrText('تمام'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationLine extends StatelessWidget {
  const _ExplanationLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: ZakerSpacing.sm),
        Expanded(
          child: TrText(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _AudioError extends StatelessWidget {
  const _AudioError({this.failure, required this.onRetry});

  final BatchFailure? failure;
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
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              failure == null
                  ? 'حصل خطأ وإحنا بنفتح الملف.'
                  : batchErrorText(failure!),
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
