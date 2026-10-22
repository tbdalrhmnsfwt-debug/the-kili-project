/// HTTP client for the Zaker AI backend.
///
/// Endpoints recovered from the shipped `libapp.so`:
///   * `https://students.moalemai.com/api`              — API base
///   * `https://students.moalemai.com/api/app-settings` — remote app settings
///   * `https://students.moalemai.com/api/billing/return/`
///   * `https://students.moalemai.com/api/image/proxy`   — image proxy
///   * `https://students.moalemai.com/tutorials`         — tutorial catalogue
///   * `https://students.moalemai.com/tutorials/index.json`
library;

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Base URL of the Zaker AI backend.
const String kApiBaseUrl = 'https://students.moalemai.com/api';

/// Root of the web companion site.
const String kSiteBaseUrl = 'https://students.moalemai.com';

/// Firebase Realtime Database instance used for live/shared state.
const String kFirebaseRtdbUrl = 'https://zakerlyai-default-rtdb.firebaseio.com';

/// Thin wrapper over [Dio] that centralises auth, error mapping and logging.
class ApiClient {
  ApiClient({Dio? dio, Logger? logger})
    : _dio = dio ?? Dio(),
      _logger = logger ?? Logger() {
    _dio.options = _dio.options.copyWith(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('→ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onError: (error, handler) {
          _logger.e('✗ ${error.requestOptions.uri}: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final Logger _logger;

  Dio get raw => _dio;

  /// Attaches the Firebase ID token to every subsequent request.
  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// Fetches the remote app settings document.
  Future<Map<String, dynamic>> fetchAppSettings() async {
    final res = await _dio.get<Map<String, dynamic>>('/app-settings');
    return res.data ?? const {};
  }

  /// Fetches the tutorial catalogue index.
  Future<List<Map<String, dynamic>>> fetchTutorials() async {
    final res = await _dio.get<List<dynamic>>('/tutorials/index.json');
    return (res.data ?? const []).cast<Map<String, dynamic>>();
  }

  /// Returns the URL the user should be redirected to after a Play Billing
  /// purchase, for receipt validation.
  String billingReturnUrl(String receipt) =>
      '$kApiBaseUrl/billing/return/$receipt';

  /// Proxies an image through the backend (used for avatar/cover images).
  String imageProxyUrl(String remoteUrl, {int width = 1080}) =>
      '$kApiBaseUrl/image/proxy?url=${Uri.encodeQueryComponent(remoteUrl)}&w=$width';

  /// Performs a request and decodes the JSON body, mapping transport errors
  /// onto a readable message.
  Future<T> guard<T>(Future<T> Function() action, {required T fallback}) async {
    try {
      return await action();
    } on DioException catch (e) {
      _logger.w('request failed: ${e.type} ${e.message}');
      return fallback;
    }
  }
}
