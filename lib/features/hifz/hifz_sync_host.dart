/// Reschedules the hifz review reminder when the saved state changes.
///
/// Mounted above the router for the whole session. It also runs on resume and
/// at local midnight so a reminder is never left on a stale date.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hifz_models.dart';
import 'hifz_providers.dart';
import 'hifz_scheduler.dart';

class HifzSyncHost extends ConsumerStatefulWidget {
  const HifzSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HifzSyncHost> createState() => _HifzSyncHostState();
}

class _HifzSyncHostState extends ConsumerState<HifzSyncHost>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sync());
      _scheduleMidnightSync();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_sync());
    _scheduleMidnightSync();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    try {
      await ref.read(hifzSchedulerProvider).syncNow();
    } catch (error) {
      debugPrint('hifz: scheduling pass failed ($error)');
    }
  }

  void _syncSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_sync());
    });
  }

  void _scheduleMidnightSync() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 5),
      () {
        unawaited(_sync());
        _scheduleMidnightSync();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HifzState>(hifzProvider, (previous, next) => _syncSoon());
    return widget.child;
  }
}
