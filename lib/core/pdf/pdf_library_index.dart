/// The immutable catalog of the user's PDFs.
///
/// Every operation returns a new index so the controller can hand updates to
/// Riverpod without mutation surprises. Flutter-free for plain-Dart tests.
library;

import '../../models/pdf_document.dart';

/// How the catalog is ordered.
enum PdfSort { name, addedAt, size }

/// The whole library, as persisted under `pdf.library.v1`.
class PdfLibraryIndex {
  const PdfLibraryIndex(this.entries);

  factory PdfLibraryIndex.empty() => const PdfLibraryIndex([]);

  factory PdfLibraryIndex.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PdfLibraryIndex.empty();
    final raw = json['documents'];
    if (raw is! List) return PdfLibraryIndex.empty();
    final entries = <PdfDocumentEntry>[];
    for (final element in raw) {
      if (element is! Map) continue;
      try {
        entries.add(
          PdfDocumentEntry.fromJson(Map<String, dynamic>.from(element)),
        );
      } on FormatException {
        // A damaged entry must never take the whole library down.
        continue;
      }
    }
    return PdfLibraryIndex(entries);
  }

  final List<PdfDocumentEntry> entries;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'documents': [for (final entry in entries) entry.toJson()],
      };

  /// The entry with [id], or null when the library does not know it.
  PdfDocumentEntry? entryById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Adds [entry], replacing the one with the same id.
  PdfLibraryIndex upsert(PdfDocumentEntry entry) {
    final next = <PdfDocumentEntry>[];
    var replaced = false;
    for (final existing in entries) {
      if (existing.id == entry.id) {
        next.add(entry);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) next.add(entry);
    return PdfLibraryIndex(next);
  }

  PdfLibraryIndex remove(String id) {
    return PdfLibraryIndex([
      for (final entry in entries)
        if (entry.id != id) entry,
    ]);
  }

  /// Drops entries whose backing file is gone.
  PdfLibraryIndex pruneMissing(
    bool Function(PdfDocumentEntry entry) fileExists,
  ) {
    return PdfLibraryIndex([
      for (final entry in entries)
        if (fileExists(entry)) entry,
    ]);
  }

  /// Filters, orders and optionally truncates the catalog.
  List<PdfDocumentEntry> query({
    String search = '',
    PdfSort sort = PdfSort.addedAt,
    bool descending = true,
    bool favoritesOnly = false,
    int? limit,
  }) {
    final needle = search.trim().toLowerCase();
    final matches = <PdfDocumentEntry>[
      for (final entry in entries)
        if ((!favoritesOnly || entry.favorite) &&
            (needle.isEmpty ||
                entry.displayName.toLowerCase().contains(needle)))
          entry,
    ];
    matches.sort(switch (sort) {
      PdfSort.name => (a, b) => a.displayName.compareTo(b.displayName),
      PdfSort.addedAt => (a, b) => (a.lastOpenedAt ?? a.addedAt).compareTo(
            b.lastOpenedAt ?? b.addedAt,
          ),
      PdfSort.size => (a, b) => a.sizeBytes.compareTo(b.sizeBytes),
    });
    if (descending) {
      final reversed = matches.reversed.toList();
      return limit == null ? reversed : reversed.take(limit).toList();
    }
    return limit == null ? matches : matches.take(limit).toList();
  }
}
