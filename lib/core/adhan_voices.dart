/// The adhan recordings bundled with the app.
///
/// Every built-in file lives in `android/app/src/main/res/raw` and is played
/// as a notification sound, so no network is needed at runtime.  The matching
/// sources, licenses and attribution text are listed in
/// `assets/adhan/LICENSES.md`; only the recordings whose license requires
/// attribution are repeated on the in-app About/Licenses screen.
///
/// A user can also drop an `egyptian_*.mp3` file in `assets/adhan/` before
/// building: [AdhanVoiceCatalog] detects those files and adds them to the
/// picker.  Such a file is played from the app's assets; to use it as a
/// notification sound as well, the same name also has to be placed in
/// `android/app/src/main/res/raw`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

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
    this.requiresAttribution = false,
    this.isFajr = false,
    this.assetPath,
    this.isCustom = false,
  });

  /// Stable id, used in the persisted settings.
  final String id;

  /// The Android raw resource name (`res/raw/<resource>.mp3`).
  final String resource;

  /// Arabic name shown in the picker.
  final String title;

  /// Credited reciter / recordist, kept for the license document.
  final String reciter;

  /// Page the recording was downloaded from, kept for the license document.
  final String sourceUrl;

  /// Short license name, e.g. «CC0 1.0».
  final String license;

  /// Canonical license URL.
  final String licenseUrl;

  /// Attribution line, required only for CC BY recordings.
  final String attribution;

  /// Whether the license requires visible attribution (currently CC BY).
  ///
  /// CC0 and public-domain recordings do not, so they stay out of the
  /// in-app licenses screen and appear only in `assets/adhan/LICENSES.md`.
  final bool requiresAttribution;

  /// A recording made for Fajr; offered as the Fajr default.
  final bool isFajr;

  /// The Flutter asset path, used by recordings the user added themselves.
  final String? assetPath;

  /// True for a recording detected in `assets/adhan/egyptian_*.mp3`.
  final bool isCustom;

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

/// All built-in voices, in picker order.  Titles are deliberately short and
/// Arabic-only: reciter names, sources and licenses live in the license
/// document, not next to the recordings in the picker.
const List<AdhanVoice> kAdhanVoices = <AdhanVoice>[
  AdhanVoice(
    id: 'aishatu',
    resource: 'adhan_aishatu',
    title: 'أذان هادئ',
    reciter: 'Aishatu98',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adhan.ogg',
    license: 'CC0 1.0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution: '"Adhan" by Aishatu98, Wikimedia Commons, CC0 1.0',
  ),
  AdhanVoice(
    id: 'beautiful',
    resource: 'adhan_beautiful',
    title: 'أذان جميل',
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
    title: 'أذان المدينة',
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
    title: 'أذان المسجد النبوي',
    reciter: 'ejaz215',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:33937_ejaz215_call-to-prayer-from-the-prophet-s-mo.ogg',
    license: 'CC BY 3.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/3.0/',
    attribution:
        '"Call to prayer from the prophet mosque" by ejaz215, Freesound '
        '(https://freesound.org/people/ejaz215/sounds/33937/), via Wikimedia '
        'Commons, CC BY 3.0 — compressed and loudness-normalised',
    requiresAttribution: true,
  ),
  AdhanVoice(
    id: 'fouad_fajr',
    resource: 'adhan_fouad_fajr',
    title: 'أذان الفجر',
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
    id: 'egyptian_cairo',
    resource: 'adhan_egyptian_cairo',
    title: 'أذان مصري',
    reciter: 'musesdelight (uploader)',
    sourceUrl:
        'https://www.masmaa.org/en/audio/morning-call-to-prayer-in-cairo',
    license: 'CC0 1.0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution:
        '"Morning Call to Prayer in Cairo" — Masmaa sound archive '
        '(masmaa.org), CC0 1.0 — compressed and loudness-normalised',
  ),
];

/// The built-in voices plus any Egyptian recordings the user added to
/// `assets/adhan/`.
///
/// Flutter assets are compiled into the APK, so this scan runs once at start
/// (see `main`).  When the folder has no `egyptian_*.mp3` file the catalog is
/// exactly [kAdhanVoices].
class AdhanVoiceCatalog {
  AdhanVoiceCatalog._();

  static final AdhanVoiceCatalog instance = AdhanVoiceCatalog._();

  static const String _assetDir = 'assets/adhan/';
  static const String _customPrefix = 'egyptian_';

  List<AdhanVoice> _voices = kAdhanVoices;
  bool _loaded = false;

  /// All voices, built-ins first.
  List<AdhanVoice> get voices => _voices;

  /// Scans the bundled assets for user-added Egyptian recordings.
  ///
  /// Missing assets, a platform without an asset manifest, or an unreadable
  /// entry simply leaves the built-in list in place.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final paths = manifest.listAssets().where(_isEgyptianRecording).toList()
        ..sort();
      if (paths.isEmpty) return;

      final custom = <AdhanVoice>[];
      for (var index = 0; index < paths.length; index++) {
        final path = paths[index];
        final file = path.substring(path.lastIndexOf('/') + 1);
        final resource = file.substring(0, file.length - '.mp3'.length);
        custom.add(
          AdhanVoice(
            id: 'custom_$resource',
            resource: resource,
            title: paths.length == 1
                ? 'أذان مصري'
                : 'أذان مصري ${_arabicNumber(index + 1)}',
            reciter: '',
            sourceUrl: '',
            license: '',
            licenseUrl: '',
            attribution: '',
            assetPath: path,
            isCustom: true,
          ),
        );
      }
      _voices = List<AdhanVoice>.unmodifiable([...kAdhanVoices, ...custom]);
    } catch (error) {
      debugPrint('adhan: could not scan assets/adhan ($error)');
    }
  }

  static bool _isEgyptianRecording(String path) {
    if (!path.startsWith(_assetDir)) return false;
    final file = path.substring(_assetDir.length);
    if (file.contains('/')) return false;
    return file.startsWith(_customPrefix) &&
        file.toLowerCase().endsWith('.mp3');
  }

  static String _arabicNumber(int value) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return value
        .toString()
        .split('')
        .map((digit) => digits[int.tryParse(digit) ?? 0])
        .join();
  }
}

/// Looks a voice up, falling back to the first voice for unknown ids.
AdhanVoice adhanVoiceById(String? id) {
  for (final voice in AdhanVoiceCatalog.instance.voices) {
    if (voice.id == id) return voice;
  }
  return kAdhanVoices.first;
}

/// Looks a voice up without a fallback.
AdhanVoice? adhanVoiceOrNull(String? id) {
  for (final voice in AdhanVoiceCatalog.instance.voices) {
    if (voice.id == id) return voice;
  }
  return null;
}
