/// Keeps the rolling azkar/salat/Kahf notification window in step with the
/// app's state.
///
/// Mounted above the router for the whole session.  It rebuilds on start,
/// resume, local midnight and any settings/location/calculation change.  The
/// debounce keeps a burst of switch taps from cancelling and rebuilding
/// hundreds of alarms repeatedly.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prayer/prayer_models.dart';
import '../prayer/prayer_providers.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_scheduler.dart';

class AzkarSyncHost extends ConsumerStatefulWidget {
  const AzkarSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AzkarSyncHost> createState() => _AzkarSyncHostState();
}

class _AzkarSyncHostState extends ConsumerState<AzkarSyncHost>
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
      await ref.read(azkarSchedulerProvider).syncNow();
    } catch (error) {
      debugPrint('azkar: scheduling pass failed ($error)');
    }
  }

  /// Coalesces settings changes caused by a single interaction.
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
    ref.listen<AzkarSettings>(azkarSettingsProvider, (previous, next) {
      _syncSoon();
    });
    ref.listen<PrayerLocation?>(prayerLocationProvider, (previous, next) {
      _syncSoon();
    });
    ref.listen<String>(
      prayerSettingsProvider.select((s) => '${s.methodId}/${s.madhabId}'),
      (previous, next) => _syncSoon(),
    );
    return widget.child;
  }
}
