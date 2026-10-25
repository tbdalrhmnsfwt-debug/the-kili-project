/// Providers for the PDF library and reader.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_store.dart';
import '../core/pdf/pdf_library_controller.dart';
import '../core/pdf/pdf_library_index.dart';
import '../core/pdf/pdf_library_repository.dart';
import '../core/pdf/pdf_library_store.dart';
import '../core/pdf/pdf_render_channel.dart';
import '../core/pdf/pdf_thumbnailer.dart';
import '../models/pdf_settings.dart';
import 'app_providers.dart';

/// The native tile renderer. Overridden in tests with a fake.
final pdfRenderChannelProvider = Provider<PdfRenderChannel>(
  (ref) => const PdfRenderChannel(),
);

/// The app-private directory layout. Overridden in `main()`.
final pdfLibraryStoreProvider = Provider<PdfLibraryStore>(
  (ref) =>
      throw UnimplementedError('pdfLibraryStoreProvider must be overridden'),
);

/// Opens an imported file just long enough to read its page count.
final pdfProbeProvider = Provider<PdfProbe>((ref) {
  final channel = ref.watch(pdfRenderChannelProvider);
  return (File file) async {
    PdfRendererHandle? handle;
    try {
      handle = await channel.open(file.path);
      return PdfProbeResult(pageCount: handle.pageCount);
    } on PdfRenderException catch (error) {
      if (error.failure == PdfRenderFailure.passwordRequired) {
        return const PdfProbeResult(encrypted: true);
      }
      rethrow;
    } finally {
      if (handle != null) await channel.close(handle.id);
    }
  };
});

/// Renders page 1 into the cache directory.
final pdfThumbnailerProvider = Provider<PdfThumbnailer>((ref) {
  return pdfThumbnailer(
    ref.watch(pdfRenderChannelProvider),
    ref.watch(pdfLibraryStoreProvider),
  );
});

/// The user's PDF catalog.
final pdfLibraryControllerProvider =
    StateNotifierProvider<PdfLibraryController, PdfLibraryIndex>((ref) {
      return PdfLibraryController(
        store: ref.watch(pdfLibraryStoreProvider),
        repository: PdfLibraryRepository(ref.watch(localStoreProvider)),
        probe: ref.watch(pdfProbeProvider),
        thumbnailer: ref.watch(pdfThumbnailerProvider),
      );
    });

/// Reader preferences, persisted under [PdfSettingsController.storeKey].
final pdfSettingsProvider =
    StateNotifierProvider<PdfSettingsController, PdfReaderSettings>((ref) {
      return PdfSettingsController(ref.watch(localStoreProvider));
    });

/// Loads, saves and updates [PdfReaderSettings].
class PdfSettingsController extends StateNotifier<PdfReaderSettings> {
  PdfSettingsController(this._store) : super(_load(_store));

  /// The key the settings JSON is stored under.
  static const String storeKey = 'pdf.settings.v1';

  final LocalStore _store;

  static PdfReaderSettings _load(LocalStore store) {
    final raw = store.getString(storeKey);
    if (raw == null) return const PdfReaderSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const PdfReaderSettings();
      return PdfReaderSettings.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      // Corrupt or foreign data must never stop the reader from opening.
      return const PdfReaderSettings();
    }
  }

  void setScrollMode(PdfScrollMode mode) {
    if (state.scrollMode == mode) return;
    _save(state.copyWith(scrollMode: mode));
  }

  void setNightMode(bool value) {
    if (state.nightMode == value) return;
    _save(state.copyWith(nightMode: value));
  }

  void setHaptics(bool value) {
    if (state.haptics == value) return;
    _save(state.copyWith(haptics: value));
  }

  void _save(PdfReaderSettings settings) {
    state = settings;
    unawaited(_store.setString(storeKey, jsonEncode(settings.toJson())));
  }
}
