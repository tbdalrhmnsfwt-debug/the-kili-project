/// Dart side of the native `PdfRenderer` channel.
///
/// Android's `PdfRenderer` is the only offline way to paint a page into a
/// clipped tile at an arbitrary zoom, so the reader asks Kotlin for tiles and
/// keeps everything else on the Dart side.
library;

import 'package:flutter/services.dart';

import 'pdf_page_geometry.dart';

/// One page's size in PDF points.
class PdfPageSize {
  const PdfPageSize(this.widthPoints, this.heightPoints);

  final double widthPoints;
  final double heightPoints;
}

/// An open native renderer.
class PdfRendererHandle {
  const PdfRendererHandle({
    required this.id,
    required this.pageCount,
    required this.pages,
  });

  final int id;
  final int pageCount;
  final List<PdfPageSize> pages;
}

/// Why a render operation failed.
enum PdfRenderFailure {
  /// The file needs a password.
  passwordRequired,

  /// The supplied password was rejected.
  wrongPassword,

  /// The document is protected and this Android version cannot unlock it.
  ///
  /// `PdfRenderer` only accepts a password from Android 15 onwards.
  passwordUnsupported,

  /// The file is not a readable PDF.
  corrupt,

  /// The platform channel is missing (tests, unsupported platform).
  unavailable,

  /// Rendering the requested tile failed.
  renderFailed,

  /// The document could not be read from or written to disk.
  storage,
}

/// A typed render failure.
class PdfRenderException implements Exception {
  const PdfRenderException(this.failure);

  final PdfRenderFailure failure;

  @override
  String toString() => 'PdfRenderException(${failure.name})';
}

/// Talks to `zaker/pdf_render`.
class PdfRenderChannel {
  const PdfRenderChannel();

  static const MethodChannel channel = MethodChannel('zaker/pdf_render');

  /// Opens [path] and returns its handle and page sizes.
  Future<PdfRendererHandle> open(String path, {String? password}) async {
    final result = await _invoke('open', {
      'path': path,
      if (password != null) 'password': password,
    });
    final map = Map<String, dynamic>.from(result as Map);
    final rawPages = map['pages'] as List? ?? const [];
    return PdfRendererHandle(
      id: (map['handle'] as num).toInt(),
      pageCount: (map['pageCount'] as num).toInt(),
      pages: [
        for (final page in rawPages)
          PdfPageSize(
            ((page as Map)['width'] as num).toDouble(),
            (page['height'] as num).toDouble(),
          ),
      ],
    );
  }

  /// Renders one clipped tile and returns PNG bytes.
  Future<Uint8List> render({
    required int handle,
    required int pageIndex,
    required double scale,
    required NormalizedRect source,
    int maxPixels = 4096,
  }) async {
    final result = await _invoke('render', {
      'handle': handle,
      'page': pageIndex,
      'scale': scale,
      'left': source.left,
      'top': source.top,
      'width': source.width,
      'height': source.height,
      'maxPixels': maxPixels,
    });
    return result as Uint8List;
  }

  /// Releases the native renderer. Never throws.
  Future<void> close(int handle) async {
    try {
      await channel.invokeMethod<void>('close', {'handle': handle});
    } catch (_) {
      // Closing is best effort; a dead channel has nothing to release.
    }
  }

  Future<Object?> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      return await channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      throw const PdfRenderException(PdfRenderFailure.unavailable);
    } on PlatformException catch (error) {
      throw PdfRenderException(_failureFor(error.code));
    }
  }

  static PdfRenderFailure _failureFor(String code) {
    return switch (code) {
      'passwordRequired' => PdfRenderFailure.passwordRequired,
      'wrongPassword' => PdfRenderFailure.wrongPassword,
      'passwordUnsupported' => PdfRenderFailure.passwordUnsupported,
      'corrupt' => PdfRenderFailure.corrupt,
      'unavailable' => PdfRenderFailure.unavailable,
      'storage' => PdfRenderFailure.storage,
      _ => PdfRenderFailure.renderFailed,
    };
  }
}
