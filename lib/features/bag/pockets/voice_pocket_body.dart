/// The voice pocket of one bag folder: recordings, one shared player.
///
/// A clip whose file vanished keeps its row and its metadata so the student
/// can still see what was there and delete the reference; it is never a crash.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization.dart';
import '../../../core/my_bag/my_bag_controller.dart';
import '../../../core/my_bag/my_bag_models.dart';
import '../../../core/theme.dart';
import '../../../providers/my_bag_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../../batches/widgets/batch_labels.dart';
import '../widgets/bag_audio_player.dart';
import '../widgets/bag_voice_recorder_sheet.dart';
import '../widgets/bag_waveform.dart';

class VoicePocketBody extends ConsumerWidget {
  const VoicePocketBody({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(myBagControllerProvider);
    final clips = bag.mediaOf(folderId).voice;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const TrText('تسجيلات صوتية'),
            actions: [
              IconButton(
                key: const Key('bag-pocket-add'),
                tooltip: context.tr('سجّل'),
                onPressed: () => _record(context, ref),
                icon: const Icon(Icons.mic_none_rounded),
              ),
            ],
          ),
          if (clips.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.mic_none_rounded,
                title: 'مفيش تسجيلات',
                message: 'سجّل شرح أو ملاحظة وسمعها في أي وقت.',
                action: FilledButton.icon(
                  onPressed: () => _record(context, ref),
                  icon: const Icon(Icons.mic_rounded),
                  label: const TrText('سجّل'),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: clips.length,
              itemBuilder: (context, index) =>
                  _VoiceRow(folderId: folderId, clip: clips[index]),
            ),
        ],
      ),
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = ref.read(myBagControllerProvider).mediaOf(folderId).voice;
    if (current.length >= kMaxVoiceClips) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('حد أقصى 100 تسجيل في المجلد.')),
      );
      return;
    }
    final recorded = await showBagVoiceRecorder(context);
    if (recorded == null) return;
    try {
      await ref.read(myBagControllerProvider.notifier).addVoiceClip(
            folderId,
            sourcePath: recorded.path,
            title: context.trf('تسجيل {0}', [current.length + 1]),
            durationMs: recorded.durationMs,
            waveform: recorded.waveform,
          );
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(content: TrText('التسجيل فاضي، جرّب تاني.')),
      );
    }
  }
}

class _VoiceRow extends ConsumerWidget {
  const _VoiceRow({required this.folderId, required this.clip});

  final String folderId;
  final MyBagVoiceClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final store = ref.watch(myBagStoreProvider);
    final file = store.voiceFile(folderId, clip.fileName);
    final available = file.existsSync();
    final player = ref.watch(bagAudioPlayerProvider);

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final active = player.clipId == clip.id;
        final playing = active && player.isPlaying;
        final progress = active && player.durationMs > 0
            ? player.positionMs / player.durationMs
            : 0.0;

        return Container(
          key: Key('bag-voice-${clip.id}'),
          margin: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            ZakerSpacing.sm,
            ZakerSpacing.lg,
            0,
          ),
          padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.55,
            ),
            borderRadius: ZakerRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    key: Key('bag-voice-play-${clip.id}'),
                    tooltip: context.tr(playing ? 'إيقاف مؤقت' : 'تشغيل'),
                    onPressed: available
                        ? () => unawaited(
                              player.toggle(
                                clipId: clip.id,
                                path: file.path,
                                durationMs: clip.durationMs,
                              ),
                            )
                        : null,
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 34,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          clip.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          formatDuration(clip.durationMs),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('bag-voice-share-${clip.id}'),
                    tooltip: context.tr('شارك'),
                    onPressed: available
                        ? () => unawaited(_share(file.path, clip.title))
                        : null,
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                  ),
                  IconButton(
                    key: Key('bag-voice-delete-${clip.id}'),
                    tooltip: context.tr('احذف'),
                    onPressed: () => unawaited(_delete(context, ref, player)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZakerSpacing.sm,
                ),
                child: BagWaveform(
                  key: const Key('bag-waveform'),
                  samples: clip.waveform,
                  progress: progress,
                  onSeek: available && clip.durationMs > 0
                      ? (fraction) => unawaited(
                            player.seek(
                              (fraction * clip.durationMs).round(),
                            ),
                          )
                      : null,
                ),
              ),
              if (!available)
                Padding(
                  key: Key('bag-voice-missing-${clip.id}'),
                  padding: const EdgeInsets.fromLTRB(
                    ZakerSpacing.md,
                    ZakerSpacing.xs,
                    ZakerSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: ZakerSpacing.xs),
                      TrText(
                        'الملف مش موجود',
                        style: muted?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _share(String path, String title) async {
    await Share.shareXFiles([XFile(path)], subject: title);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BagAudioPlayer player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: TrText(context.trf('حذف «{0}»؟', [clip.title])),
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
    if (player.clipId == clip.id) await player.stop();
    await ref
        .read(myBagControllerProvider.notifier)
        .deleteVoiceClip(folderId, clip.id);
  }
}
