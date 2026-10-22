/// Accounts and authentication.
///
/// The shipped app uses Firebase Authentication (`firebase_auth` is in its
/// dependency manifest). This service speaks the same Identity Toolkit REST API
/// so the replica does not need `google-services.json` or a native Firebase
/// initialisation: the Web API key is read from the remote `app-settings`
/// document (or entered once in the account screen).
///
/// When no key is configured, or the network is unavailable, the app keeps a
/// local guest identity so every live feature still has a stable uid. Guests
/// are never sent anywhere.
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// The signed-in user (a Firebase account or a local guest).
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email = '',
    this.displayName = 'ضيف',
    this.isAnonymous = true,
    this.idToken,
  });

  final String uid;
  final String email;
  final String displayName;
  final bool isAnonymous;

  /// The Firebase ID token, absent for guests.
  final String? idToken;

  AuthUser copyWith({String? displayName, String? idToken}) => AuthUser(
    uid: uid,
    email: email,
    displayName: displayName ?? this.displayName,
    isAnonymous: isAnonymous,
    idToken: idToken ?? this.idToken,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'isAnonymous': isAnonymous,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    uid: json['uid'] as String? ?? '',
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'ضيف',
    isAnonymous: json['isAnonymous'] as bool? ?? true,
  );
}

/// Thrown when an authentication call cannot be completed.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Signs users in, out and keeps the API client's bearer token in sync.
class AuthService {
  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  AuthUser? _current;
  String _apiKey = '';

  /// The account currently in use, or `null` before the first sign-in.
  AuthUser? get currentUser => _current;

  static const String _identityBase =
      'https://identitytoolkit.googleapis.com/v1/accounts';

  /// Restores a previously persisted account and its token.
  void restore(AuthUser user, {String? idToken}) {
    _current = user.copyWith(idToken: idToken);
    _api.setAuthToken(idToken);
  }

  /// Creates the local guest identity with a stable uid.
  AuthUser startGuest({required String uid, String displayName = 'ضيف'}) {
    _current = AuthUser(
      uid: uid,
      displayName: displayName,
      isAnonymous: true,
    );
    _api.setAuthToken(null);
    return _current!;
  }

  /// Signs in with email and password.
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
    required String apiKey,
  }) => _call('signInWithPassword', email: email, password: password, apiKey: apiKey);

  /// Creates a Firebase account with email and password.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String apiKey,
    String? displayName,
  }) => _call(
    'signUp',
    email: email,
    password: password,
    apiKey: apiKey,
    displayName: displayName,
  );

  Future<AuthUser> _call(
    String method, {
    required String email,
    required String password,
    required String apiKey,
    String? displayName,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AuthException('مفيش مفتاح تسجيل متاح — سجّل دخول كضيف.');
    }
    _apiKey = apiKey;
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '$_identityBase:$method?key=${Uri.encodeQueryComponent(apiKey)}',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final token = data['idToken'] as String?;
      final uid = data['localId'] as String?;
      if (token == null || uid == null) {
        throw const AuthException('رد غير متوقع من خدمة الحسابات.');
      }
      final user = AuthUser(
        uid: uid,
        email: data['email'] as String? ?? email,
        displayName:
            data['displayName'] as String? ??
            (email.split('@').first),
        isAnonymous: false,
        idToken: token,
      );
      _current = user;
      _api.setAuthToken(token);
      return user;
    } on DioException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Updates the display name of the signed-in account.
  Future<AuthUser> updateDisplayName(String name) async {
    final user = _current;
    if (user == null) return AuthUser(uid: '', displayName: name);
    final token = user.idToken;
    if (token != null && _apiKey.isNotEmpty) {
      try {
        await _api.raw.post<Map<String, dynamic>>(
          '$_identityBase:update?key=${Uri.encodeQueryComponent(_apiKey)}',
          data: {
            'idToken': token,
            'displayName': name,
            'returnSecureToken': true,
          },
        );
      } on DioException catch (e) {
        debugPrint('auth: display name update failed ($e)');
      }
    }
    final updated = user.copyWith(displayName: name);
    _current = updated;
    return updated;
  }

  /// Clears the session.
  Future<void> signOut() async {
    _current = null;
    _api.setAuthToken(null);
  }

  static String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) {
        return switch (message.split(' : ').first) {
          'EMAIL_EXISTS' => 'الإيميل ده مسجّل بالفعل.',
          'EMAIL_NOT_FOUND' => 'مفيش حساب بالإيميل ده.',
          'INVALID_PASSWORD' => 'كلمة السر غلط.',
          'INVALID_EMAIL' => 'الإيميل مش صح.',
          'WEAK_PASSWORD' => 'كلمة السر ضعيفة — ٦ حروف على الأقل.',
          'TOO_MANY_ATTEMPTS_TRY_LATER' => 'محاولات كتير — جرّب بعد شوية.',
          'OPERATION_NOT_ALLOWED' => 'تسجيل الإيميل مش مفعّل على السيرفر.',
          _ => 'تعذّر تسجيل الدخول ($message).',
        };
      }
    }
    return 'تعذّر الاتصال بخدمة الحسابات.';
  }
}

/// A stable random uid for the local guest profile.
String newGuestUid() {
  final random = Random.secure();
  final bytes = List<int>.generate(9, (_) => random.nextInt(256));
  return 'guest-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}
