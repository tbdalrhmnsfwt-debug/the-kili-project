/// Persisted state for the two local tours.
///
/// Only the mode, the step, the batch the tour was opened from and a
/// completed flag are stored, under a per-account key. Nothing about the
/// batch's content is written here.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/key_value_store.dart';
import 'batch_tutorial_steps.dart';

const String _keyPrefix = 'batches.tutorial.v1.';

class BatchTutorialProgress {
  const BatchTutorialProgress({
    this.mode,
    this.step = 1,
    this.batchId = '',
    this.completed = false,
  });

  final BatchTutorialMode? mode;
  final int step;
  final String batchId;
  final bool completed;

  bool get isStarted => mode != null;

  List<BatchTutorialStep> get steps =>
      mode == null ? const [] : tutorialStepsFor(mode!);

  BatchTutorialStep? get current {
    final list = steps;
    if (list.isEmpty) return null;
    final index = step.clamp(1, list.length) - 1;
    return list[index];
  }

  bool get isLast => steps.isNotEmpty && step >= steps.length;

  BatchTutorialProgress copyWith({
    BatchTutorialMode? mode,
    int? step,
    String? batchId,
    bool? completed,
  }) =>
      BatchTutorialProgress(
        mode: mode ?? this.mode,
        step: step ?? this.step,
        batchId: batchId ?? this.batchId,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        if (mode != null) 'mode': mode!.name,
        'step': step,
        'batchId': batchId,
        'completed': completed,
      };

  factory BatchTutorialProgress.fromJson(Map<String, dynamic> json) {
    final mode = switch (json['mode']) {
      'full' => BatchTutorialMode.full,
      'gettingStarted' => BatchTutorialMode.gettingStarted,
      _ => null,
    };
    final rawStep = json['step'];
    final step = rawStep is int && rawStep > 0 ? rawStep : 1;
    return BatchTutorialProgress(
      mode: mode,
      step: step,
      batchId: json['batchId'] is String ? json['batchId'] as String : '',
      completed: json['completed'] == true,
    );
  }
}

/// Drives one tour and writes each change back to the key-value store.
class BatchTutorialController extends StateNotifier<BatchTutorialProgress> {
  BatchTutorialController(this._store, this._uid)
      : super(_restore(_store, _uid));

  final KeyValueStore _store;
  final String _uid;

  static BatchTutorialProgress _restore(KeyValueStore store, String uid) {
    if (uid.isEmpty) return const BatchTutorialProgress();
    final raw = store.getString('$_keyPrefix$uid');
    if (raw == null || raw.trim().isEmpty) {
      return const BatchTutorialProgress();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BatchTutorialProgress.fromJson(decoded);
      }
    } on FormatException {
      // A corrupt marker starts the tour from the beginning.
    }
    return const BatchTutorialProgress();
  }

  /// Starts (or restarts) [mode] at [step], clamped to the tour's length.
  void begin(
    BatchTutorialMode mode, {
    int step = 1,
    String batchId = '',
  }) {
    final steps = tutorialStepsFor(mode);
    state = BatchTutorialProgress(
      mode: mode,
      step: step.clamp(1, steps.length),
      batchId: batchId,
      completed: false,
    );
    _persist();
  }

  void goTo(int step) {
    if (!state.isStarted) return;
    final steps = state.steps;
    state = state.copyWith(
      step: step.clamp(1, steps.length),
      completed: step >= steps.length ? state.completed : false,
    );
    _persist();
  }

  void next() {
    if (!state.isStarted) return;
    if (state.isLast) {
      finish();
      return;
    }
    goTo(state.step + 1);
  }

  void back() => goTo(state.step - 1);

  /// Marks the tour complete without closing it.
  void finish() {
    if (!state.isStarted) return;
    state = state.copyWith(step: state.steps.length, completed: true);
    _persist();
  }

  /// Called when the overlay closes so the last step is durable.
  void close() => _persist();

  void _persist() {
    if (_uid.isEmpty) return;
    unawaited(
      _store.setString(
        '$_keyPrefix$_uid',
        jsonEncode(state.toJson()),
      ),
    );
  }
}
