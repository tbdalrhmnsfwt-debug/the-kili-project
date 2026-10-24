/// Safe, resumable downloads of official Ministry PDFs.
///
/// The service:
///   * accepts only the two Ministry PDF hosts (and re-checks redirects);
///   * downloads to a `.part` file and supports HTTP Range resume;
///   * retries transient failures with bounded exponential backoff;
///   * validates content type, PDF signature and readability;
///   * computes SHA-256 and moves the file into place atomically;
///   * never overwrites or deletes a previously verified PDF.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/official_book.dart';
import 'book_storage.dart';
import 'pdf_readability.dart';

/// A progress update for the UI.
class DownloadProgress {
  const DownloadProgress({
    required this.received,
    this.total = 0,
  });

  final int received;
  final int total;

  /// `null` when the server did not publish a content length.
  double? get fraction =>
      total <= 0 ? null : (received / total).clamp(0.0, 1.0);

  int get percent => ((fraction ?? 0) * 100).round();
}

/// The result of a completed, validated download.
class BookDownloadOutcome {
  const BookDownloadOutcome({
    required this.filePath,
    required this.fileSize,
    required this.sha256,
    required this.pageCount,
    required this.hasTextLayer,
    required this.wasExisting,
    required this.downloadedAt,
    this.etag = '',
    this.lastModified = '',
  });

  final String filePath;
  final int fileSize;
  final String sha256;
  final int pageCount;
  final bool hasTextLayer;
  final bool wasExisting;
  final DateTime downloadedAt;
  final String etag;
  final String lastModified;
}

/// The result of asking the server whether a newer file exists.
class BookUpdateCheck {
  const BookUpdateCheck({
    required this.checkedAt,
    required this.changed,
    this.etag = '',
    this.lastModified = '',
    this.contentLength = 0,
    this.error = '',
  });

  final DateTime checkedAt;
  final bool changed;
  final String etag;
  final String lastModified;
  final int contentLength;
  final String error;
}

/// Downloads official PDFs into a [BookStorageLayout].
class BookDownloadService {
  BookDownloadService({
    required this.layout,
    Dio? dio,
    this.urlPolicy = const OfficialBookUrlPolicy(),
    this.readabilityProbe = const SyncfusionPdfReadabilityProbe(),
    this.maxAttempts = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.receiveTimeout = const Duration(minutes: 4),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 25),
               sendTimeout: const Duration(seconds: 25),
               receiveTimeout: receiveTimeout,
               followRedirects: true,
               maxRedirects: 5,
               headers: const {
                 'User-Agent': 'ThakirPro/1.1 (official study library)',
                 'Accept': 'application/pdf,application/octet-stream;q=0.9,*/*;q=0.1',
               },
             ),
           );

  final BookStorageLayout layout;
  final OfficialBookUrlPolicy urlPolicy;
  final PdfReadabilityProbe readabilityProbe;
  final int maxAttempts;
  final Duration retryBaseDelay;
  final Duration receiveTimeout;
  final Dio _dio;

  /// Downloads [book], resuming an existing `.part` when possible.
  Future<BookDownloadOutcome> download(
    OfficialBook book, {
    CancelToken? cancelToken,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (!book.hasDownload) {
      throw BookOperationException(
        BookFailureKind.notAvailable,
        book.status == OfficialBookStatus.notPublished
            ? 'الكتاب ده لسه ما اتنشرش رسميًا، فمفيش رابط ننزّله.'
            : book.statusExplanation,
      );
    }

    final uri = urlPolicy.requireDownloadUrl(book.downloadUrl);
    await layout.ensureBookDirectory(book);
    final finalFile = layout.finalFile(book);

    if (await finalFile.exists()) {
      // A crash may have happened after the atomic move but before the state
      // was persisted. Re-validate the real file instead of downloading again.
      final outcome = await _validateExisting(book, finalFile);
      return outcome;
    }

    final partial = layout.partialFile(book);
    if (await partial.exists() && await partial.length() == 0) {
      await partial.delete();
    }

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (cancelToken?.isCancelled ?? false) {
        throw const BookOperationException(
          BookFailureKind.cancelled,
          'اتلغى التنزيل. الملف الجزئي محفوظ ويمكن نكمّل بعدين.',
        );
      }
      try {
        return await _attemptDownload(
          book: book,
          uri: uri,
          cancelToken: cancelToken,
          onProgress: onProgress,
          allowRestart: true,
        );
      } on BookOperationException catch (error) {
        if (!_shouldRetry(error) || attempt >= maxAttempts) rethrow;
        await _backoff(attempt, cancelToken);
      } on DioException catch (error) {
        final mapped = _mapDioException(error);
        if (!_shouldRetry(mapped) || attempt >= maxAttempts) throw mapped;
        await _backoff(attempt, cancelToken);
      }
    }
    throw const BookOperationException(
      BookFailureKind.unknown,
      'التنزيل فشل بعد عدة محاولات. جرّب تاني بعد شوية.',
    );
  }

  Future<BookDownloadOutcome> _attemptDownload({
    required OfficialBook book,
    required Uri uri,
    required CancelToken? cancelToken,
    required void Function(DownloadProgress progress)? onProgress,
    required bool allowRestart,
  }) async {
    final partial = layout.partialFile(book);
    var start = await partial.exists() ? await partial.length() : 0;

    final headers = <String, Object>{};
    if (start > 0) headers['range'] = 'bytes=$start-';

    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (_) => true,
          headers: headers,
          receiveTimeout: receiveTimeout,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }

    final status = response.statusCode ?? 0;
    if (status == HttpStatus.requestedRangeNotSatisfiable && allowRestart) {
      // The saved range no longer matches the file on the server. Start over
      // from zero once, keeping any previously verified final file untouched.
      if (await partial.exists()) await partial.delete();
      return _attemptDownload(
        book: book,
        uri: uri,
        cancelToken: cancelToken,
        onProgress: onProgress,
        allowRestart: false,
      );
    }
    if (status != HttpStatus.ok &&
        status != HttpStatus.partialContent) {
      throw BookOperationException(
        BookFailureKind.http,
        _httpMessage(status),
        statusCode: status,
      );
    }

    urlPolicy.requireFinalUrl(response.realUri);
    _requirePdfContentType(response.headers);

    final contentLength = _intHeader(
      response.headers.value(Headers.contentLengthHeader),
    );
    final contentRange = response.headers.value('content-range');
    final rangeTotal = _rangeTotal(contentRange);

    var total = status == HttpStatus.partialContent
        ? (rangeTotal ?? (contentLength > 0 ? start + contentLength : 0))
        : contentLength;

    // A server may ignore `Range` and answer 200 with the full file.
    if (status == HttpStatus.ok && start > 0) start = 0;
    if (status == HttpStatus.ok) {
      total = contentLength;
    }

    final sink = partial.openWrite(
      mode: start > 0 ? FileMode.append : FileMode.write,
    );
    var received = start;
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final stream = response.data?.stream;
      if (stream == null) {
        throw const BookOperationException(
          BookFailureKind.network,
          'السيرفر رجّع رد فاضي. جرّب تاني.',
        );
      }
      await for (final chunk in stream) {
        if (cancelToken?.isCancelled ?? false) {
          throw const BookOperationException(
            BookFailureKind.cancelled,
            'اتلغى التنزيل. الملف الجزئي محفوظ ويمكن نكمّل بعدين.',
          );
        }
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (onProgress != null &&
            now.difference(lastReport) > const Duration(milliseconds: 120)) {
          lastReport = now;
          onProgress(DownloadProgress(received: received, total: total));
        }
      }
      await sink.flush();
    } on DioException catch (error) {
      throw _mapDioException(error);
    } finally {
      await sink.close();
    }
    onProgress?.call(DownloadProgress(received: received, total: total));

    final size = await partial.length();
    if (size < 512) {
      await _discard(partial);
      throw const BookOperationException(
        BookFailureKind.signature,
        'الملف اللي نزل صغير جدًا ومش كتاب كامل. جرّب تاني.',
      );
    }
    await _requirePdfSignature(partial);

    final PdfReadability readability;
    try {
      readability = await readabilityProbe.probe(partial);
    } on BookOperationException {
      await _discard(partial);
      rethrow;
    }

    final digest = await sha256.bind(partial.openRead()).first;
    final sha = digest.toString();
    final finalFile = layout.finalFile(book);
    final now = DateTime.now();
    if (await finalFile.exists()) {
      // Preserve the previously verified edition; never delete it.
      final previous = layout.previousFile(book, now);
      await finalFile.rename(previous.path);
    }
    await partial.rename(finalFile.path);

    final outcome = BookDownloadOutcome(
      filePath: finalFile.path,
      fileSize: size,
      sha256: sha,
      pageCount: readability.pageCount,
      hasTextLayer: readability.hasTextLayer,
      wasExisting: false,
      downloadedAt: now,
      etag: response.headers.value('etag') ?? '',
      lastModified: response.headers.value('last-modified') ?? '',
    );
    await _writeManifest(book, outcome);
    return outcome;
  }

  Future<BookDownloadOutcome> _validateExisting(
    OfficialBook book,
    File file,
  ) async {
    await _requirePdfSignature(file);
    final readability = await readabilityProbe.probe(file);
    final size = await file.length();
    final digest = await sha256.bind(file.openRead()).first;
    final stat = await file.stat();
    final outcome = BookDownloadOutcome(
      filePath: file.path,
      fileSize: size,
      sha256: digest.toString(),
      pageCount: readability.pageCount,
      hasTextLayer: readability.hasTextLayer,
      wasExisting: true,
      downloadedAt: stat.modified,
    );
    await _writeManifest(book, outcome);
    return outcome;
  }

  /// Asks the server for the current validators and length.
  ///
  /// A failed check is reported, not thrown: the student keeps the downloaded
  /// copy and sees an Arabic warning.
  Future<BookUpdateCheck> checkForUpdate(
    OfficialBook book,
    BookLocalState state, {
    CancelToken? cancelToken,
  }) async {
    final checkedAt = DateTime.now();
    try {
      if (!book.hasDownload) {
        return BookUpdateCheck(
          checkedAt: checkedAt,
          changed: false,
          error: 'مفيش رابط رسمي متاح للكتاب ده.',
        );
      }
      final uri = urlPolicy.requireDownloadUrl(book.downloadUrl);
      final response = await _dio.head<void>(
        uri.toString(),
        options: Options(
          followRedirects: true,
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 45),
        ),
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 0;
      if (status == HttpStatus.methodNotAllowed || status == 501) {
        return BookUpdateCheck(
          checkedAt: checkedAt,
          changed: false,
          error: 'السيرفر مش بيسمح بفحص التحديث دلوقتي. جرّب بعدين.',
        );
      }
      if (status < 200 || status >= 300) {
        return BookUpdateCheck(
          checkedAt: checkedAt,
          changed: false,
          error: _httpMessage(status),
        );
      }
      urlPolicy.requireFinalUrl(response.realUri);
      final etag = response.headers.value('etag') ?? '';
      final lastModified = response.headers.value('last-modified') ?? '';
      final length = _intHeader(
        response.headers.value(Headers.contentLengthHeader),
      );
      final etagChanged =
          etag.isNotEmpty && state.etag.isNotEmpty && etag != state.etag;
      final modifiedChanged =
          lastModified.isNotEmpty &&
          state.lastModified.isNotEmpty &&
          lastModified != state.lastModified;
      final lengthChanged =
          length > 0 && state.fileSize > 0 && length != state.fileSize;
      final metadataChanged =
          state.downloadedMetadataVersion.isNotEmpty &&
          book.metadataVersion != state.downloadedMetadataVersion;
      return BookUpdateCheck(
        checkedAt: checkedAt,
        changed: etagChanged || modifiedChanged || lengthChanged || metadataChanged,
        etag: etag,
        lastModified: lastModified,
        contentLength: length,
      );
    } on BookOperationException catch (error) {
      return BookUpdateCheck(
        checkedAt: checkedAt,
        changed: false,
        error: error.message,
      );
    } on DioException catch (error) {
      return BookUpdateCheck(
        checkedAt: checkedAt,
        changed: false,
        error: _mapDioException(error).message,
      );
    } catch (error) {
      return BookUpdateCheck(
        checkedAt: checkedAt,
        changed: false,
        error: 'مش قادرين نتحقق من التحديث ($error).',
      );
    }
  }

  Future<void> _writeManifest(
    OfficialBook book,
    BookDownloadOutcome outcome,
  ) async {
    try {
      final manifest = {
        'saved_at': DateTime.now().toIso8601String(),
        'catalog': book.toJson(),
        'download': {
          'file_path': outcome.filePath,
          'file_size': outcome.fileSize,
          'sha256': outcome.sha256,
          'page_count': outcome.pageCount,
          'has_text_layer': outcome.hasTextLayer,
          'downloaded_at': outcome.downloadedAt.toIso8601String(),
          'etag': outcome.etag,
          'last_modified': outcome.lastModified,
        },
      };
      final target = layout.manifestFile(book);
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      await temp.rename(target.path);
    } catch (_) {
      // The state store remains authoritative; a sidecar failure must not fail
      // a validated download.
    }
  }

  Future<void> _requirePdfSignature(File file) async {
    final handle = await file.open();
    try {
      final length = await handle.length();
      final readLength = length < 1024 ? length : 1024;
      final head = await handle.read(readLength);
      final marker = ascii.encode('%PDF-');
      if (!_contains(head, marker)) {
        await _discard(file);
        throw const BookOperationException(
          BookFailureKind.signature,
          'الملف اللي نزل مش PDF صالح — غالبًا صفحة خطأ من السيرفر.',
        );
      }
    } finally {
      await handle.close();
    }
  }

  void _requirePdfContentType(Headers headers) {
    final raw = headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    if (raw.isEmpty) return; // signature validation still applies
    final allowed =
        raw.contains('application/pdf') ||
        raw.contains('application/octet-stream') ||
        raw.contains('binary/octet-stream');
    if (!allowed) {
      throw BookOperationException(
        BookFailureKind.contentType,
        'السيرفر رجّع نوع ملف غير متوقع ($raw) بدل PDF.',
      );
    }
  }

  bool _shouldRetry(BookOperationException error) {
    return switch (error.kind) {
      BookFailureKind.network || BookFailureKind.timeout => true,
      BookFailureKind.http =>
        error.statusCode == null ||
            error.statusCode == 408 ||
            error.statusCode == 429 ||
            error.statusCode! >= 500,
      _ => false,
    };
  }

  Future<void> _backoff(int attempt, CancelToken? cancelToken) async {
    final delay = retryBaseDelay * (1 << (attempt - 1));
    final steps = delay.inMilliseconds ~/ 100;
    for (var i = 0; i < steps; i++) {
      if (cancelToken?.isCancelled ?? false) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _discard(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing else to do; the next attempt will overwrite it.
    }
  }

  BookOperationException _mapDioException(DioException error) {
    if (CancelToken.isCancel(error) ||
        error.type == DioExceptionType.cancel) {
      return const BookOperationException(
        BookFailureKind.cancelled,
        'اتلغى التنزيل. الملف الجزئي محفوظ ويمكن نكمّل بعدين.',
      );
    }
    final status = error.response?.statusCode;
    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'السيرفر اتأخر في الرد. جرّب تاني.',
      DioExceptionType.connectionError =>
        'مفيش اتصال بالسيرفر. اتأكد من النت وجرّب تاني.',
      DioExceptionType.badCertificate => 'شهادة الأمان للسيرفر غير صالحة.',
      DioExceptionType.badResponse => _httpMessage(status ?? 0),
      _ => 'التنزيل وقف بسبب مشكلة في الشبكة. جرّب تاني.',
    };
    return BookOperationException(
      error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout
          ? BookFailureKind.timeout
          : error.type == DioExceptionType.connectionError
          ? BookFailureKind.network
          : BookFailureKind.http,
      message,
      cause: error,
      statusCode: status,
    );
  }
}

int _intHeader(String? value) => int.tryParse(value?.trim() ?? '') ?? 0;

int? _rangeTotal(String? value) {
  if (value == null) return null;
  final match = RegExp(r'/\s*(\d+)\s*$').firstMatch(value);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

bool _contains(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return true;
  }
  return false;
}

String _httpMessage(int status) => switch (status) {
  400 => 'الطلب غير صالح لدى السيرفر الرسمي.',
  401 || 403 => 'السيرفر الرسمي رفض الوصول للرابط.',
  404 => 'الرابط مش موجود على السيرفر الرسمي (404).',
  408 => 'السيرفر اتأخر في الرد (408).',
  416 => 'الملف الجزئي مش متوافق مع النسخة الحالية.',
  429 => 'في طلبات كتير على السيرفر. استنى شوية وجرّب تاني.',
  500 || 502 || 503 || 504 =>
    'السيرفر الرسمي فيه مشكلة مؤقتة ($status). جرّب تاني بعد شوية.',
  _ => 'السيرفر رجّع خطأ $status.',
};
