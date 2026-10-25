/// Reads and writes the PDF catalog as one JSON value in [KeyValueStore].
library;

import 'dart:convert';

import '../key_value_store.dart';
import 'pdf_library_index.dart';

/// Persists the catalog under a single prefixed key.
class PdfLibraryRepository {
  PdfLibraryRepository(this._store);

  /// Store key for the catalog.
  static const String storeKey = 'pdf.library.v1';

  final KeyValueStore _store;

  /// Loads the catalog; a missing or corrupt value yields an empty library.
  PdfLibraryIndex load() {
    final raw = _store.getString(storeKey);
    if (raw == null) return PdfLibraryIndex.empty();
    try {
      final decoded = jsonDecode(raw);
      return PdfLibraryIndex.fromJson(
        decoded is Map<String, dynamic> ? decoded : null,
      );
    } catch (_) {
      return PdfLibraryIndex.empty();
    }
  }

  /// Writes the catalog. The store never throws.
  Future<void> save(PdfLibraryIndex index) =>
      _store.setString(storeKey, jsonEncode(index.toJson()));
}
