/// The annotations that live on top of a PDF page.
///
/// Coordinates are normalized page coordinates (0..1, origin at the top-left
/// of the unrotated page), exactly like [NormalizedRect], so an annotation
/// survives zoom, rotation and a different screen size. The model is
/// Flutter-free: the UI and the PDF exporter both read the same values, and a
/// plain-Dart harness can verify a saved project without a widget tree.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'pdf_page_geometry.dart';

/// Everything a reader can put on a page.
enum PdfAnnotationKind {
  highlight,
  underline,
  strike,
  ink,
  note,
  text,
  image,
  stamp,
  arrow,
  audio,
  video;

  /// Whether this annotation is drawn as a mark over existing text.
  bool get isMark =>
      this == highlight || this == underline || this == strike || this == ink;

  /// Whether this annotation owns a file outside the PDF.
  bool get hasMedia => this == image || this == audio || this == video;

  /// The studio's default accent for this kind (ARGB).
  int get defaultColor => switch (this) {
        highlight => 0xFFFFD84D,
        underline => 0xFF35BCE8,
        strike => 0xFFE5484D,
        ink => 0xFF4779FF,
        note => 0xFFF5D45A,
        text => 0xFFF2F6FF,
        image => 0xFF7C5CFF,
        stamp => 0xFF3DDC97,
        arrow => 0xFFF5D45A,
        audio => 0xFF7C5CFF,
        video => 0xFF35BCE8,
      };
}

/// One coordinate-anchored annotation.
class PdfAnnotation {
  const PdfAnnotation({
    required this.id,
    required this.pageIndex,
    required this.kind,
    required this.rect,
    int? color,
    this.opacity = 1,
    this.text = '',
    this.mediaPath,
    this.mediaName = '',
    this.mediaBytes = 0,
    this.durationMs = 0,
    required this.createdAt,
  }) : color = color ?? 0;

  /// Stable id used by undo and by the project manifest.
  final String id;

  /// Zero-based page index.
  final int pageIndex;

  final PdfAnnotationKind kind;

  /// Position on the unrotated page.
  final NormalizedRect rect;

  /// ARGB colour; zero means [PdfAnnotationKind.defaultColor].
  final int color;

  /// 0.1–1.0. The UI multiplies this into the painted colour.
  final double opacity;

  /// Sticky-note body or inserted text.
  final String text;

  /// App-private absolute path for image/audio/video annotations.
  final String? mediaPath;

  final String mediaName;
  final int mediaBytes;

  /// Audio/video length, when the picker could not tell us (zero is fine).
  final int durationMs;

  final DateTime createdAt;

  /// The effective colour, falling back to the kind's accent.
  int get effectiveColor => color == 0 ? kind.defaultColor : color;

  PdfAnnotation copyWith({
    String? id,
    int? pageIndex,
    PdfAnnotationKind? kind,
    NormalizedRect? rect,
    int? color,
    double? opacity,
    String? text,
    String? mediaPath,
    String? mediaName,
    int? mediaBytes,
    int? durationMs,
    DateTime? createdAt,
  }) {
    return PdfAnnotation(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      kind: kind ?? this.kind,
      rect: rect ?? this.rect,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      text: text ?? this.text,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaName: mediaName ?? this.mediaName,
      mediaBytes: mediaBytes ?? this.mediaBytes,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// A short, filesystem-safe extension for packaged media.
  String get mediaExtension {
    final path = mediaPath ?? mediaName;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'bin';
    final value = path.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(value) ? value : 'bin';
  }

  /// Serializes the annotation.
  ///
  /// [mediaReference] is the archive-relative path used by project packages.
  /// [includeMediaPath] writes the app-private absolute path instead, which is
  /// what the per-document store needs so an attachment survives reopening.
  /// The two are never written together: a manifest must not contain device
  /// paths.
  Map<String, dynamic> toJson({
    String? mediaReference,
    bool includeMediaPath = false,
  }) =>
      {
        'id': id,
        'page': pageIndex,
        'kind': kind.name,
        'rect': [rect.left, rect.top, rect.width, rect.height],
        if (color != 0) 'color': color,
        'opacity': opacity,
        if (text.isNotEmpty) 'text': text,
        if (mediaReference != null) 'media': mediaReference,
        if (includeMediaPath && mediaReference == null && mediaPath != null)
          'mediaPath': mediaPath,
        if (mediaName.isNotEmpty) 'mediaName': mediaName,
        if (mediaBytes > 0) 'mediaBytes': mediaBytes,
        if (durationMs > 0) 'duration': durationMs,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// Reads a serialized annotation.
  ///
  /// [includeMediaPath] is only for the app's own store. Project manifests are
  /// untrusted input, so they never get to name a device path: their media is
  /// reattached from the package's `attachments/` entries.
  factory PdfAnnotation.fromJson(
    Map<String, dynamic> json, {
    bool includeMediaPath = false,
  }) {
    final id = json['id'];
    final page = json['page'];
    final rect = json['rect'];
    final kind = json['kind'];
    if (id is! String || page is! num || rect is! List || rect.length != 4) {
      throw const FormatException('invalid pdf annotation');
    }
    final values = [
      for (final value in rect)
        if (value is num) value.toDouble() else 0.0,
    ];
    final normalized = NormalizedRect(
      values[0],
      values[1],
      values[2],
      values[3],
    ).clampToPage();
    final parsedKind = PdfAnnotationKind.values.firstWhere(
      (value) => value.name == kind,
      orElse: () => PdfAnnotationKind.highlight,
    );
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return PdfAnnotation(
      id: id,
      pageIndex: math.max(0, page.toInt()),
      kind: parsedKind,
      rect: normalized,
      color: (json['color'] as num?)?.toInt() ?? 0,
      opacity: ((json['opacity'] as num?)?.toDouble() ?? 1)
          .clamp(0.1, 1.0)
          .toDouble(),
      text: json['text'] as String? ?? '',
      mediaPath: !includeMediaPath
          ? null
          : switch (json['mediaPath']) {
              final String path when path.trim().isNotEmpty => path,
              _ => null,
            },
      mediaName: json['mediaName'] as String? ?? '',
      mediaBytes: (json['mediaBytes'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  /// The value stored in a project manifest for [mediaPath].
  String? get mediaReference =>
      mediaPath == null ? null : 'attachments/$id.$mediaExtension';

  @override
  String toString() =>
      'PdfAnnotation($id, ${kind.name}, page $pageIndex, ${rect.left}, '
      '${rect.top}, ${rect.width}, ${rect.height})';
}

/// The JSON of an annotation list, as persisted per document.
///
/// Absolute media paths are included: the app copied those files into its own
/// private folder, and without the path a saved audio note would reopen as a
/// card with nothing behind it. Project manifests use
/// [PdfAnnotation.toJson]'s `mediaReference` instead.
String encodePdfAnnotations(List<PdfAnnotation> annotations) {
  return jsonEncode([
    for (final annotation in annotations)
      annotation.toJson(includeMediaPath: true),
  ]);
}

/// Reads an annotation list; a damaged value yields an empty list.
List<PdfAnnotation> decodePdfAnnotations(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final result = <PdfAnnotation>[];
    for (final element in decoded) {
      if (element is! Map) continue;
      try {
        result.add(
          PdfAnnotation.fromJson(
            Map<String, dynamic>.from(element),
            includeMediaPath: true,
          ),
        );
      } on Object {
        // One damaged annotation must not drop the rest. `Object` rather than
        // `FormatException`: a mistyped field throws a TypeError, and that
        // must not wipe the whole document's notes.
      }
    }
    return result;
  } on Object {
    return const [];
  }
}

/// The shared-preferences key holding one document's annotations.
String pdfAnnotationsStoreKey(String docKey) {
  final safe = docKey.trim().isEmpty ? 'session' : docKey.trim();
  return 'pdf.studio.annotations.v1.$safe';
}
