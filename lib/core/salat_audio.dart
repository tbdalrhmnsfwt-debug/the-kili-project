/// The three salat-on-the-Prophet phrases and their optional recordings.
///
/// No third-party recording of these exact phrases was available under a
/// public-domain, CC0 or CC-BY licence when the feature was built, so the app
/// starts with no voice files.  The generated short chime is bundled in
/// `assets/salat/chime.mp3` and `res/raw/salat_chime.mp3`.
///
/// A user can add their own recording to `assets/salat/` using one of the
/// filename patterns below.  [SalatAudioCatalog] detects the first matching
/// file per phrase.  It can be previewed in the app; Android can only use a
/// raw resource as a notification-channel sound, so an asset-only file leaves
/// the notification silent and the phrase is still shown as text.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// How a phrase reminder should sound.
enum SalatSoundMode {
  /// Play the recording when one is available.
  voice,

  /// Play the app's short chime.
  chime,

  /// No sound; the notification still vibrates when vibration is on.
  silent;

  String get wireName => name;

  static SalatSoundMode fromWire(Object? value) {
    return switch (value) {
      'voice' => SalatSoundMode.voice,
      'silent' => SalatSoundMode.silent,
      _ => SalatSoundMode.chime,
    };
  }
}

/// One of the exact phrases the user can choose.
@immutable
class SalatPhrase {
  const SalatPhrase({required this.id, required this.text});

  /// Stable id used by the settings, the filename pattern and the payload.
  final String id;

  /// The exact Arabic phrase shown in the notification and on screen.
  final String text;

  /// The filename prefix for a user-added recording.
  String get filePrefix => id;

  /// The progress / counter key for this phrase.
  String get counterId => 'salat_$id';

  @override
  bool operator ==(Object other) => other is SalatPhrase && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The three requested phrases, in presentation order.
const List<SalatPhrase> kSalatPhrases = <SalatPhrase>[
  SalatPhrase(id: 'asal_ala_muhammad', text: 'صلِّ على محمد'),
  SalatPhrase(id: 'asal_ala_sayyidina_muhammad', text: 'صلِّ على سيدنا محمد'),
  SalatPhrase(
    id: 'allahumma_salli',
    text: 'اللهم صلِّ وسلِّم وزد وبارك على سيدنا محمد',
  ),
];

/// The ids of [kSalatPhrases], in order.
final List<String> kSalatPhraseIds = List<String>.unmodifiable(
  kSalatPhrases.map((phrase) => phrase.id),
);

/// The phrase with [id], or `null` when it is not one of the three.
SalatPhrase? salatPhraseOrNull(String? id) {
  for (final phrase in kSalatPhrases) {
    if (phrase.id == id) return phrase;
  }
  return null;
}

/// Looks a phrase up, falling back to the first one.
SalatPhrase salatPhraseById(String? id) =>
    salatPhraseOrNull(id) ?? kSalatPhrases.first;

/// The raw notification sound bundled with the app.
const String kSalatChimeResource = 'salat_chime';

/// The Flutter asset path of the same chime, used for in-app previews.
const String kSalatChimeAsset = 'assets/salat/chime.mp3';

/// The catalog of recordings available for the three phrases.
///
/// It starts empty and is filled once at start-up by [load].  A missing
/// manifest or an unreadable folder simply leaves the catalog empty.
class SalatAudioCatalog {
  SalatAudioCatalog._();

  static final SalatAudioCatalog instance = SalatAudioCatalog._();

  static const String _assetDir = 'assets/salat/';

  Map<String, String> _customAssets = const <String, String>{};
  Map<String, List<String>> _allCustomAssets = const <String, List<String>>{};
  bool _loaded = false;

  /// The first user-added asset for [phraseId], or `null`.
  String? customAssetFor(String phraseId) => _customAssets[phraseId];

  /// Every user-added asset detected for [phraseId].
  List<String> customAssetsFor(String phraseId) =>
      _allCustomAssets[phraseId] ?? const <String>[];

  /// Whether this phrase has any recording that can be previewed in-app.
  bool canPreview(String phraseId) => customAssetFor(phraseId) != null;

  /// The raw resource Android can use as a notification sound, or `null`.
  ///
  /// The app currently bundles no phrase voices, so this returns `null`.
  /// A future build can add a raw resource and return its name here without
  /// changing the scheduler.
  String? notificationResourceFor(String phraseId) => null;

  /// Whether this phrase has a raw resource that Android can use as a
  /// notification sound.
  bool canSoundNotification(String phraseId) =>
      notificationResourceFor(phraseId) != null;

  /// Whether any recording exists for [phraseId] at all.
  bool hasRecording(String phraseId) => canPreview(phraseId);

  /// Scans `assets/salat/<phrase_id>_*.mp3` once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final found = <String, List<String>>{};
      for (final path in manifest.listAssets()) {
        if (!path.startsWith(_assetDir)) continue;
        final file = path.substring(_assetDir.length);
        if (file.contains('/')) continue;
        if (!file.toLowerCase().endsWith('.mp3')) continue;
        for (final phrase in kSalatPhrases) {
          if (file.startsWith('${phrase.filePrefix}_')) {
            found.putIfAbsent(phrase.id, () => <String>[]).add(path);
            break;
          }
        }
      }
      if (found.isEmpty) return;
      for (final paths in found.values) {
        paths.sort();
      }
      _allCustomAssets = found.map(
        (id, paths) => MapEntry(id, List<String>.unmodifiable(paths)),
      );
      _customAssets = found.map((id, paths) => MapEntry(id, paths.first));
      debugPrint(
        'salat: detected ${_customAssets.length} user-added phrase recording(s)',
      );
    } catch (error) {
      debugPrint('salat: could not scan $_assetDir ($error)');
    }
  }
}
