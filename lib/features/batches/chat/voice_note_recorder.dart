/// Records one chat voice note: permission, level meter, 15-minute cap.
///
/// The widget never sends the message itself. It returns a finished
/// [RecordedClip] to the caller, which copies it into the batch and indexes it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/audio_recorder_channel.dart';
import '../../../core/theme.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/tr_text.dart';
import '../widgets/batch_labels.dart';

class VoiceNoteRecorder extends ConsumerStatefulWidget {
  const VoiceNoteRecorder({super.key});

  @override
  ConsumerState<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

enum _Stage { preparing, denied, lowStorage, recording, stopping, failed }

class _VoiceNoteRecorderState extends ConsumerState<VoiceNoteRecorder> {
  static const int maxDurationMs = 15 * 60 * 1000;

  /// A 15-minute AAC note is about 7 MB; below this the recording would fail
  /// halfway, so it is refused before the microphone opens.
  static const int minFreeBytes = 10 * 1024 * 1024;

  late final AudioRecorderBindings _bindings;
  _Stage _stage = _Stage.preparing;
  String? _error;
  String? _tempName;
  int _elapsedMs = 0;
  int _amplitude = 0;
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  StreamSubscription<RecorderTick>? _ticks;
  bool _disposed = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _bindings = ref.read(audioRecorderBindingsProvider);
    _prepare();
  }

  Future<void> _prepare() async {
    if (_disposed || _starting) return;
    _starting = true;
    setState(() {
      _stage = _Stage.preparing;
      _error = null;
    });
    try {
      final granted = await _bindings.hasPermission() ||
          await _bindings.requestPermission();
      if (_disposed) return;
      if (!granted) {
        setState(() => _stage = _Stage.denied);
        return;
      }
      final free = await _bindings.freeBytes();
      if (_disposed) return;
      if (free > 0 && free < minFreeBytes) {
        setState(() => _stage = _Stage.lowStorage);
        return;
      }
      await _startRecording();
    } on AudioRecorderException catch (error) {
      if (_disposed) return;
      setState(() {
        _stage = error.isPermissionDenied ? _Stage.denied : _Stage.failed;
        _error = error.code;
      });
    } on Object {
      if (_disposed) return;
      setState(() {
        _stage = _Stage.failed;
        _error = 'recordFailed';
      });
    } finally {
      _starting = false;
    }
  }

  Future<void> _startRecording() async {
    // A repeated start must not leave the previous timer and tick listener
    // running alongside the new recording.
    _timer?.cancel();
    _timer = null;
    final previousTicks = _ticks;
    _ticks = null;
    await previousTicks?.cancel();
    _tempName = 'voice-${DateTime.now().microsecondsSinceEpoch.toString()}.m4a';
    await _bindings.start(_tempName!);
    if (_disposed) {
      await _bindings.cancel();
      return;
    }
    _watch
      ..reset()
      ..start();
    _ticks = _bindings.ticks.listen(_onTick);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_watch.isRunning) return;
      final elapsed = _watch.elapsedMilliseconds;
      if (elapsed >= maxDurationMs) {
        _stop();
        return;
      }
      setState(() => _elapsedMs = elapsed);
    });
    setState(() {
      _stage = _Stage.recording;
      _elapsedMs = 0;
      _amplitude = 0;
    });
  }

  void _onTick(RecorderTick tick) {
    if (_disposed || _stage != _Stage.recording) return;
    setState(() {
      _amplitude = tick.amplitude;
      if (tick.elapsedMs > _elapsedMs) _elapsedMs = tick.elapsedMs;
    });
    if (tick.maxReached) _stop();
  }

  Future<void> _stop() async {
    if (_stage != _Stage.recording) return;
    setState(() => _stage = _Stage.stopping);
    _watch.stop();
    _timer?.cancel();
    _timer = null;
    await _ticks?.cancel();
    _ticks = null;
    try {
      final clip = await _bindings.stop();
      if (_disposed) return;
      Navigator.of(context).pop(clip);
    } on AudioRecorderException catch (error) {
      if (_disposed) return;
      setState(() {
        _stage = _Stage.failed;
        _error = error.code;
      });
    } on Object {
      if (_disposed) return;
      setState(() {
        _stage = _Stage.failed;
        _error = 'recordFailed';
      });
    }
  }

  Future<void> _cancel() async {
    _watch.stop();
    _timer?.cancel();
    _timer = null;
    await _ticks?.cancel();
    _ticks = null;
    try {
      await _bindings.cancel();
    } on AudioRecorderException {
      // A recorder that already stopped has nothing left to cancel.
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _disposed = true;
    _watch.stop();
    _timer?.cancel();
    _ticks?.cancel();
    if (_stage == _Stage.recording || _stage == _Stage.stopping) {
      // Leaving the sheet by the system back gesture must not leave the
      // microphone running.
      unawaited(_bindings.cancel().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != _Stage.recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage == _Stage.recording) _cancel();
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            0,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHeader(),
              const SizedBox(height: ZakerSpacing.lg),
              ..._content(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    final theme = Theme.of(context);
    switch (_stage) {
      case _Stage.preparing:
        return [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: ZakerSpacing.lg),
            child: CircularProgressIndicator(),
          ),
          const TrText('بنجهز الميكروفون…'),
        ];
      case _Stage.denied:
        return [
          Icon(
            Icons.mic_off_rounded,
            size: 42,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          const TrText(
            'إذن الميكروفون مرفوض. من غير الإذن مقدرناش نسجل رسالة صوتية. '
            'تقدر تطلب الإذن تاني، وباقي التطبيق شغال عادي.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const TrText('إلغاء'),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _prepare,
                  child: const TrText('اطلب الإذن تاني'),
                ),
              ),
            ],
          ),
        ];
      case _Stage.lowStorage:
        return [
          Icon(
            Icons.sd_card_alert_outlined,
            size: 42,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          const TrText(
            'مساحة الجهاز قربت تخلص. التسجيل محتاج مساحة أكبر عشان '
            'مايتقطعش في النص. فضّي مساحة وجرّب تاني.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const TrText('إلغاء'),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _prepare,
                  child: const TrText('جرّب تاني'),
                ),
              ),
            ],
          ),
        ];
      case _Stage.recording:
        return [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZakerSpacing.md,
              vertical: ZakerSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_manual_record_rounded,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  formatDuration(_elapsedMs),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _LevelMeter(amplitude: _amplitude),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            'الحد الأقصى ١٥ دقيقة. لو سبت الشاشة، التسجيل هيتوقف ويتحفظ.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.close_rounded),
                  label: const TrText('إلغاء'),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.check_rounded),
                  label: const TrText('خلّص'),
                ),
              ),
            ],
          ),
        ];
      case _Stage.stopping:
        return [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: ZakerSpacing.lg),
            child: CircularProgressIndicator(),
          ),
          const TrText('بنحفظ التسجيل…'),
        ];
      case _Stage.failed:
        final permission = _error == 'permissionDenied';
        return [
          Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            permission
                ? 'إذن الميكروفون اتقفل قبل بدء التسجيل.'
                : 'التسجيل ما نجحش. يمكن الميكروفون مشغول بتطبيق تاني.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const TrText('إلغاء'),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _prepare,
                  child: const TrText('جرّب تاني'),
                ),
              ),
            ],
          ),
        ];
    }
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
        const SizedBox(width: ZakerSpacing.sm),
        const Expanded(
          child: TrText(
            'رسالة صوتية',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        TrText(
          'محفوظة على الجهاز',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A bar meter driven by the recorder's real peak amplitude.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.amplitude});

  final int amplitude;

  static const List<double> _shape = [0.35, 0.6, 0.9, 0.55, 1, 0.45, 0.75];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final level = (amplitude / 32767).clamp(0.0, 1.0);
    final scale = 0.15 + 0.85 * math.sqrt(level);
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final factor in _shape)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                width: 7,
                height: 8 + 32 * factor * scale,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.35 + 0.65 * level,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
