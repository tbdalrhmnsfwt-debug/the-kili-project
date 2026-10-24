/// The adhan recordings bundled with the app.
///
/// Every file lives in `android/app/src/main/res/raw` and is played as a
/// notification sound, so no network is needed at runtime.  The matching
/// sources, licenses and attribution text are also listed in
/// `assets/adhan/LICENSES.md` and on the in-app credits screen.
library;

import 'package:flutter/foundation.dart';

/// One bundled recording.
@immutable
class AdhanVoice {
  const AdhanVoice({
    required this.id,
    required this.resource,
    required this.title,
    required this.reciter,
    required this.sourceUrl,
    required this.license,
    required this.licenseUrl,
    required this.attribution,
    this.isTakbeer = false,
    this.isFajr = false,
  });

  /// Stable id, used in the persisted settings.
  final String id;

  /// The Android raw resource name (`res/raw/<resource>.mp3`).
  final String resource;

  /// Arabic name shown in the picker.
  final String title;

  /// Credited reciter / recordist.
  final String reciter;

  /// Page the recording was downloaded from.
  final String sourceUrl;

  /// Short license name, e.g. «CC0 1.0».
  final String license;

  /// Canonical license URL.
  final String licenseUrl;

  /// Attribution line shown on the credits screen.
  final String attribution;

  /// The very short takbeer-only clip.
  final bool isTakbeer;

  /// A recording made for Fajr; offered as the Fajr default.
  final bool isFajr;

  /// One channel per voice: Android channel sounds cannot be changed after
  /// creation, so selecting another voice simply selects another channel.
  String get channelId => 'zaker_adhan_$id';

  @override
  bool operator ==(Object other) => other is AdhanVoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The default voice for Fajr … Isha.
const String kDefaultAdhanVoiceId = 'aishatu';

/// The default Fajr voice (a different recording, as requested).
const String kDefaultFajrVoiceId = 'fouad_fajr';

/// All bundled voices, in picker order.
const List<AdhanVoice> kAdhanVoices = <AdhanVoice>[
  AdhanVoice(
    id: 'aishatu',
    resource: 'adhan_aishatu',
    title: 'أذان هادئ — Aishatu98',
    reciter: 'Aishatu98',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adhan.ogg',
    license: 'CC0 1.0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution: '"Adhan" by Aishatu98, Wikimedia Commons, CC0 1.0',
  ),
  AdhanVoice(
    id: 'beautiful',
    resource: 'adhan_beautiful',
    title: 'أذان جميل — Adam-synagda',
    reciter: 'Adam-synagda',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg',
    license: 'CC0 1.0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution:
        '"Beautiful adhan" by Adam-synagda, Wikimedia Commons, CC0 1.0',
  ),
  AdhanVoice(
    id: 'madeenah',
    resource: 'adhan_madeenah',
    title: 'أذان المدينة — B9.',
    reciter: 'B9.',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Oraci%C3%B3n_Al-Azzan.ogg',
    license: 'Public domain',
    licenseUrl: 'https://creativecommons.org/publicdomain/mark/1.0/',
    attribution: '"Oración Al-Azzan" by B9., Wikimedia Commons, public domain',
  ),
  AdhanVoice(
    id: 'ejaz215',
    resource: 'adhan_ejaz215',
    title: 'أذان المسجد النبوي — ejaz215',
    reciter: 'ejaz215',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg',
    license: 'CC BY 3.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/3.0/',
    attribution:
        '"Call to prayer from the prophet mosque" by ejaz215, Freesound '
        '(https://freesound.org/people/ejaz215/sounds/33937/), via Wikimedia '
        'Commons, CC BY 3.0 — compressed and loudness-normalised',
  ),
  AdhanVoice(
    id: 'fouad_fajr',
    resource: 'adhan_fouad_fajr',
    title: 'أذان الفجر — فؤاد عدن',
    reciter: 'Fouad Adan',
    sourceUrl: 'https://archive.org/details/AdanAlfajrFouadAdan',
    license: 'Public Domain Mark 1.0',
    licenseUrl: 'https://creativecommons.org/publicdomain/mark/1.0/',
    attribution:
        '"Adhan Fouad Adan" by Fouad Adan, Internet Archive, Public Domain '
        'Mark 1.0 — compressed and loudness-normalised',
    isFajr: true,
  ),
  AdhanVoice(
    id: 'takbeer',
    resource: 'takbeer_short',
    title: 'تكبير قصير — Bod lnga klang',
    reciter: 'Bod lnga klang',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Allahuakbar.opus',
    license: 'CC0 1.0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution: '"Allahuakbar" by Bod lnga klang, Wikimedia Commons, CC0 1.0',
    isTakbeer: true,
  ),
];

/// Looks a voice up, falling back to the first voice for unknown ids.
AdhanVoice adhanVoiceById(String? id) {
  for (final voice in kAdhanVoices) {
    if (voice.id == id) return voice;
  }
  return kAdhanVoices.first;
}

/// Looks a voice up without a fallback.
AdhanVoice? adhanVoiceOrNull(String? id) {
  for (final voice in kAdhanVoices) {
    if (voice.id == id) return voice;
  }
  return null;
}
