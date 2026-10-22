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

/// Data source tags for phrases.
///
/// The upstream dataset tags each phrase with `src`, whose observed values
/// are `both` (agreement between two corpora) and single-corpus tags.
enum PhraseSource { both, single, unknown }

/// One phrase occurrence (`t` + alignment metadata).
class Phrase {
  const Phrase({
    required this.text,
    required this.startSurah,
    required this.startAya,
    required this.endSurah,
    required this.endAya,
    required this.source,
    required this.tier,
  });

  final String text;
  final String startSurah;
  final int startAya;
  final String endSurah;
  final int endAya;
  final PhraseSource source;
  final String tier; // A / B / C

  @override
  String toString() => '$text $startSurah:${startAya}-$endSurah:$endAya';
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
  });

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
  static MutashabihatData parse(File file) {
    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return MutashabihatData(
      version: decoded['version'] as String? ?? '3',
      builtAt: decoded['built'] as String? ?? '',
      sourceFiles: [
        ...((decoded['sources'] as List?) ?? const []).cast<String>(),
      ],
      phraseTiers: _tiers(decoded['phrase_tiers']),
      occurrenceTiers: _tiers(decoded['occurrence_tiers']),
      similarTiers: _tiers(decoded['similar_tiers']),
    );
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

  static List<Phrase> parsePhrases(File file) {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final out = <Phrase>[];
    for (final p in (decoded['phrases'] as List?) ?? const []) {
      final m = p as Map<String, dynamic>;
      out.add(
        Phrase(
          text: m['t'] as String? ?? '',
          startSurah: m['surah'] as String? ?? '',
          startAya:
              (m['start_aya'] as num?)?.toInt() ??
              (m['startAya'] as num?)?.toInt() ??
              0,
          endSurah: m['end_surah'] as String? ?? '',
          endAya:
              (m['end_aya'] as num?)?.toInt() ??
              (m['endAya'] as num?)?.toInt() ??
              0,
          source: switch (m['src'] as String? ?? '') {
            'both' => PhraseSource.both,
            '' => PhraseSource.unknown,
            _ => PhraseSource.single,
          },
          tier: m['tier'] as String? ?? 'B',
        ),
      );
    }
    return out;
  }

  static List<Map<String, dynamic>> parsePairs(File file) {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (decoded['pairs'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
  }
}
