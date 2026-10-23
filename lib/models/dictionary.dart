/// Models backing the on-side dictionary (`assets/dictionary/words.json`)
/// and the adhkar / occasional-word lookup tables.
library;

import 'dart:convert';
import 'dart:io';

/// A single dictionary entry: Arabic headword -> English translation.
///
/// The bundled file is `{"v": 2, "e": [{"s": "words", "en": "...", "ar": "..."}]}`.
class WordEntry {
  const WordEntry({
    required this.surahTitle,
    required this.english,
    required this.arabic,
  });

  final String surahTitle;
  final String english;
  final String arabic;

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
    surahTitle: json['s'] as String? ?? '',
    english: json['en'] as String? ?? '',
    arabic: json['ar'] as String? ?? '',
  );
}

/// A dictionary word loaded from `words.json`.
class DictionaryEntry {
  const DictionaryEntry({required this.entries, required this.sources});

  /// All words in the dictionary, in file order.
  final List<WordEntry> entries;

  /// Optional per-surah provenance map `surahNo -> [source files]`.
  final Map<String, List<String>> sources;

  /// Number of words in the dictionary.
  int get length => entries.length;

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['e'] as List? ?? const [];
    return DictionaryEntry(
      entries: raw
          .map((e) => WordEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      sources: <String, List<String>>{},
    );
  }

  static DictionaryEntry fromFile(File file) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return DictionaryEntry.fromJson(json);
  }
}

/// A Surah reference within a chapter listing.
class SurahReference {
  const SurahReference({
    required this.name,
    required this.startAya,
    required this.endAya,
    this.taf = '',
  });

  final String name;
  final int startAya;
  final int endAya;
  final String taf;

  factory SurahReference.fromName(
    String name, {
    int startAya = 0,
    int endAya = 0,
    String taf = '',
  }) =>
      SurahReference(name: name, startAya: startAya, endAya: endAya, taf: taf);
}

/// A grouped tafiration / reference table (`meta`, `lists`).
class ReferenceList {
  const ReferenceList({
    required this.name,
    required this.items,
    this.source = 'builtin',
  });

  final String name;
  final List<SurahReference> items;
  final String source;

  factory ReferenceList.fromJson(Map<String, dynamic> json) {
    final raw =
        (json['lists'] as List?)?.cast<Map<String, dynamic>>() ??
        (json['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    return ReferenceList(
      name: json['name'] as String? ?? '',
      items: raw
          .map(
            (e) => SurahReference(
              name: e['name'] as String? ?? '',
              startAya:
                  (e['start_aya'] as num?)?.toInt() ??
                  (e['startAya'] as num?)?.toInt() ??
                  0,
              endAya:
                  (e['end_aya'] as num?)?.toInt() ??
                  (e['endAya'] as num?)?.toInt() ??
                  0,
              taf: e['taf'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      source: json['source'] as String? ?? 'builtin',
    );
  }
}

/// One repeated phrase and the verses it appears in.
class MutashabihatPhrase {
  const MutashabihatPhrase({required this.text, required this.refs});

  final String text;

  /// Verse references such as `2:23`, in dataset order.
  final List<String> refs;
}

/// A pair of similar verses (`source` ↔ `related`).
class MutashabihatPair {
  const MutashabihatPair({required this.source, required this.related});

  final String source;
  final String related;
}

/// The full mutashabihat dataset split into its recovered sub-tables:
/// phrases, pairs, similar, popular.
class MutashabihatData {
  MutashabihatData({
    required this.version,
    required this.builtAt,
    required this.sourceFiles,
    required this.phraseTiers,
    required this.occurrenceTiers,
    required this.similarTiers,
    this.phrases = const [],
    this.pairs = const [],
  });

  /// The repeated phrases with every verse they occur in.
  final List<MutashabihatPhrase> phrases;

  /// Pairs of verses the dataset marks as similar.
  final List<MutashabihatPair> pairs;

  /// Dataset version, as shipped in the `version` field.
  final String version;

  /// Build timestamp recorded by the dataset generator.
  final String builtAt;

  /// The corpus files the dataset was rebuilt from.
  final List<String> sourceFiles;

  /// Counts per rule tier for the phrase table.
  final Map<String, int> phraseTiers;

  /// Counts per rule tier for the occurrence table.
  final Map<String, int> occurrenceTiers;

  /// Counts per rule tier for the "similar phrases" table.
  final Map<String, int> similarTiers;

  /// Parsed from the gzipped `mutashabihat.json` inside
  /// `assets/quran/mutashabihat.json.gz`.
  static MutashabihatData parse(File file) => parseJson(file.readAsStringSync());

  /// Parses the decompressed dataset JSON.
  static MutashabihatData parseJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return MutashabihatData(
      version: '${decoded['version'] ?? 3}',
      builtAt: decoded['built'] as String? ?? '',
      sourceFiles: [
        ...((decoded['sources'] as List?) ?? const []).cast<String>(),
      ],
      phraseTiers: _tiers(decoded['phrase_tiers']),
      occurrenceTiers: _tiers(decoded['occurrence_tiers']),
      similarTiers: _tiers(decoded['similar_tiers']),
      phrases: _parsePhraseTable(decoded['phrases']),
      pairs: _parsePairTable(decoded['pairs']),
    );
  }

  /// `phrases: [{ "t": text, "o": [[ref, start, end, src, tier], …] }]`
  static List<MutashabihatPhrase> _parsePhraseTable(dynamic raw) {
    final out = <MutashabihatPhrase>[];
    if (raw is! List) return out;
    for (final row in raw) {
      if (row is! Map) continue;
      final text = row['t'] as String? ?? '';
      if (text.isEmpty) continue;
      final refs = <String>[];
      for (final occurrence in (row['o'] as List?) ?? const []) {
        if (occurrence is List && occurrence.isNotEmpty) {
          refs.add('${occurrence.first}');
        }
      }
      if (refs.isEmpty) continue;
      out.add(MutashabihatPhrase(text: text, refs: refs));
    }
    return out;
  }

  /// `pairs: { "101:6": [[1503, "7:8"], …], … }`
  static List<MutashabihatPair> _parsePairTable(dynamic raw) {
    final out = <MutashabihatPair>[];
    if (raw is! Map) return out;
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! List) continue;
      for (final pair in value) {
        if (pair is! List || pair.length < 2) continue;
        out.add(
          MutashabihatPair(
            source: '${entry.key}',
            related: '${pair[1]}',
          ),
        );
      }
    }
    return out;
  }

  static Map<String, int> _tiers(dynamic obj) {
    final out = <String, int>{};
    if (obj is! Map) return out;
    for (final e in obj.entries) {
      out[e.key as String] = (e.value as num).toInt();
    }
    return out;
  }

  /// Rules tier counts derived from the rebuilt data.
  Map<String, int> get phraseTiersCount => phraseTiers;
  Map<String, int> get occurrenceTiersCount => occurrenceTiers;
  Map<String, int> get similarTiersCount => similarTiers;

}
