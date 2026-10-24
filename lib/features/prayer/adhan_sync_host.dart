/// Keeps the rolling adhan window in step with the app's state.
///
/// Mounted above the router, so it lives for the whole app session.  It does
/// not tick a timer for the countdown; it only asks the scheduler to rebuild
/// when something that affects the times actually changes.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adhan_models.dart';
import 'adhan_providers.dart';
import 'adhan_scheduler.dart';
import 'prayer_models.dart';
import 'prayer_providers.dart';

class AdhanSyncHost extends ConsumerStatefulWidget {
  const AdhanSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdhanSyncHost> createState() => _AdhanSyncHostState();
}

class _AdhanSyncHostState extends ConsumerState<AdhanSyncHost>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After the first frame the providers have their persisted values and
      // the plugin can be initialised without delaying startup.
      unawaited(_sync());
      _scheduleMidnightSync();
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The user may have changed the timezone, granted a permission or moved
    // while the app was in the background.
    unawaited(_sync());
    _scheduleMidnightSync();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    try {
      await ref.read(prayerAdhanSchedulerProvider).syncNow();
    } catch (error) {
      debugPrint('adhan: scheduling pass failed ($error)');
    }
  }

  /// Rebuilds the window just after each local midnight, so "today" keeps
  /// rolling forward even if the app is left open all night.
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
    ref.listen<AdhanSettings>(adhanSettingsProvider, (previous, next) {
      unawaited(_sync());
    });
    ref.listen<PrayerLocation?>(prayerLocationProvider, (previous, next) {
      unawaited(_sync());
    });
    ref.listen<String>(
      prayerSettingsProvider.select((s) => '${s.methodId}/${s.madhabId}'),
      (previous, next) {
        unawaited(_sync());
      },
    );
    return widget.child;
  }
}
