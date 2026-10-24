/// Shared access to the Quran text the reader already uses.
///
/// The text and the surah index come from the public AlQuran Cloud API
/// (`https://api.alquran.cloud/v1`), the same service family the original app
/// uses. Both the reader and the hifz mode go through this one cache, so a
/// surah fetched by either is available to the other without a second request.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Base of the AlQuran Cloud API.
const String kQuranApi = 'https://api.alquran.cloud/v1';

/// Mishary Alafasy, 128 kbps — one file per surah.
const String kQuranAudioBase =
    'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy';

/// A surah as returned by the AlQuran Cloud index.
class QuranSurah {
  const QuranSurah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.ayahCount,
    required this.revelation,
  });

  final int number;
  final String name;
  final String englishName;
  final int ayahCount;
  final String revelation;

  factory QuranSurah.fromJson(Map<String, dynamic> json) {
    final type = json['revelationType'] as String? ?? '';
    return QuranSurah(
      number: (json['number'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      ayahCount: (json['numberOfAyahs'] as num?)?.toInt() ?? 0,
      revelation: type == 'Medinan' ? 'مدنية' : 'مكية',
    );
  }
}

/// Fetches and caches the surah index and each surah's ayah texts.
class QuranData {
  QuranData(this._dio);

  final Dio _dio;

  List<QuranSurah>? _surahs;
  final Map<int, List<String>> _ayahs = {};

  /// The surah index, fetched once unless [refresh] is set.
  Future<List<QuranSurah>> surahs({bool refresh = false}) async {
    final cached = _surahs;
    if (cached != null && !refresh) return cached;
    final response = await _dio.get<Map<String, dynamic>>('$kQuranApi/surah');
    final data = (response.data ?? const {})['data'] as List<dynamic>?;
    final parsed = (data ?? const [])
        .map((e) => QuranSurah.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _surahs = parsed;
    return parsed;
  }

  /// The ayah texts of [surahNumber], 1-based, cached per surah.
  Future<List<String>> ayahsFor(int surahNumber, {bool refresh = false}) async {
    final cached = _ayahs[surahNumber];
    if (cached != null && !refresh) return cached;
    final response = await _dio.get<Map<String, dynamic>>(
      '$kQuranApi/surah/$surahNumber',
    );
    final data = (response.data ?? const {})['data'] as Map<String, dynamic>?;
    final parsed = ((data?['ayahs'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map<String, dynamic>)['text'] as String? ?? '')
        .toList(growable: false);
    _ayahs[surahNumber] = parsed;
    return parsed;
  }

  /// The surah whose number is [number], or null before the index loads.
  QuranSurah? surahByNumber(int number) {
    for (final surah in _surahs ?? const <QuranSurah>[]) {
      if (surah.number == number) return surah;
    }
    return null;
  }
}

/// The app-wide Quran data cache.
final quranDataProvider = Provider<QuranData>(
  (ref) => QuranData(ref.watch(apiClientProvider).raw),
);
