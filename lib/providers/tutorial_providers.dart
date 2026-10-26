/// The local tour controller for the active account.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/batches/tutorial/batch_tutorial_progress.dart';
import 'app_providers.dart';

final batchTutorialControllerProvider = StateNotifierProvider.autoDispose<
    BatchTutorialController, BatchTutorialProgress>((ref) {
  final uid = ref.watch(authUserProvider)?.uid ?? '';
  return BatchTutorialController(ref.watch(localStoreProvider), uid);
});
