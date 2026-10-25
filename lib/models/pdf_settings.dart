/// Reader preferences that survive a restart.
///
/// Only presentation choices live here; document content, passwords and
/// search queries never do.
library;

/// How the reader lays pages out.
enum PdfScrollMode { vertical, horizontal }

/// The reader's persisted preferences.
class PdfReaderSettings {
  const PdfReaderSettings({
    this.scrollMode = PdfScrollMode.vertical,
    this.nightMode = false,
    this.haptics = true,
  });

  final PdfScrollMode scrollMode;
  final bool nightMode;
  final bool haptics;

  Map<String, dynamic> toJson() => {
    'scroll': scrollMode.name,
    'night': nightMode,
    'haptics': haptics,
  };

  /// Reads stored settings, falling back to the defaults for anything missing
  /// or unrecognised.
  factory PdfReaderSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PdfReaderSettings();
    return PdfReaderSettings(
      scrollMode: PdfScrollMode.values.firstWhere(
        (mode) => mode.name == json['scroll'],
        orElse: () => PdfScrollMode.vertical,
      ),
      nightMode: json['night'] == true,
      haptics: json['haptics'] != false,
    );
  }

  PdfReaderSettings copyWith({
    PdfScrollMode? scrollMode,
    bool? nightMode,
    bool? haptics,
  }) {
    return PdfReaderSettings(
      scrollMode: scrollMode ?? this.scrollMode,
      nightMode: nightMode ?? this.nightMode,
      haptics: haptics ?? this.haptics,
    );
  }
}
