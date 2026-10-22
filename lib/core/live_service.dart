/// Live shared state: the weekly leaderboard and the direct challenges.
///
/// The original app keeps both in Firebase Realtime Database at
/// [kFirebaseRtdbUrl]. This service uses the RTDB REST API, so it needs no
/// Firebase SDK, no `google-services.json` and no platform channels:
///
///   * `leaderboard/<week>/<uid>.json` — one row per player, per week.
///   * `challenges/<id>.json`          — open / live / finished challenges.
///   * `results/<id>/<uid>.json`       — the scores sent back by players.
///
/// Reads and writes are opt-in ([LiveConfig.enabled]). The app stays fully
/// usable offline: every method returns `null` or an empty list when the
/// service is disabled or unreachable, and the screens fall back to the
/// locally derived data.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/arena.dart';
import '../models/leaderboard.dart';
import 'api_client.dart';

/// Connection settings for the live backend.
class LiveConfig {
  const LiveConfig({
    this.enabled = false,
    this.databaseUrl = kFirebaseRtdbUrl,
    this.idToken,
  });

  /// Whether the app may talk to the shared backend at all.
  final bool enabled;

  /// The Realtime Database URL.
  final String databaseUrl;

  /// The Firebase ID token used for authenticated reads/writes.
  final String? idToken;

  LiveConfig copyWith({
    bool? enabled,
    String? databaseUrl,
    String? idToken,
  }) => LiveConfig(
    enabled: enabled ?? this.enabled,
    databaseUrl: databaseUrl ?? this.databaseUrl,
    idToken: idToken ?? this.idToken,
  );
}

/// REST client for the live backend.
class LiveService {
  LiveService(this._api);

  final ApiClient _api;

  /// Whether [config] allows reaching the backend.
  static bool canSync(LiveConfig config) =>
      config.enabled && config.databaseUrl.trim().isNotEmpty;

  Map<String, dynamic> _query(LiveConfig config) => {
    if (config.idToken != null && config.idToken!.isNotEmpty)
      'auth': config.idToken,
  };

  String _url(LiveConfig config, String path) =>
      '${config.databaseUrl.replaceAll(RegExp(r'/+$'), '')}/$path.json';

  /// The row of every player for [weekStart], or `null` when offline.
  Future<List<LeaderboardRow>?> fetchLeaderboard(
    DateTime weekStart,
    LiveConfig config, {
    String? myUid,
  }) async {
    if (!canSync(config)) return null;
    try {
      final res = await _api.raw.get<Map<String, dynamic>>(
        _url(config, 'leaderboard/${weekKey(weekStart)}'),
        queryParameters: _query(config),
      );
      final data = res.data;
      if (data == null) return const [];
      final rows = <LeaderboardRow>[];
      data.forEach((uid, value) {
        if (value is! Map) return;
        final json = value.map((k, v) => MapEntry('$k', v));
        final row = LeaderboardRow.fromJson(json);
        rows.add(
          LeaderboardRow(
            userId: row.userId.isEmpty ? uid : row.userId,
            displayName: row.displayName.isEmpty ? 'لاعب' : row.displayName,
            points: row.points,
            focusSeconds: row.focusSeconds,
            solved: row.solved,
            streak: row.streak,
            isMe: uid == myUid,
          ),
        );
      });
      return rows;
    } on DioException catch (e) {
      debugPrint('live: leaderboard unavailable (${e.type.name})');
      return null;
    } catch (e) {
      debugPrint('live: leaderboard parse failed ($e)');
      return null;
    }
  }

  /// Publishes [row] under `leaderboard/<week>/<uid>`.
  Future<bool> publishRow(
    DateTime weekStart,
    LeaderboardRow row,
    LiveConfig config,
  ) async {
    if (!canSync(config)) return false;
    try {
      await _api.raw.put<void>(
        _url(config, 'leaderboard/${weekKey(weekStart)}/${row.userId}'),
        data: row.toJson(),
        queryParameters: _query(config),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('live: could not publish the score (${e.type.name})');
      return false;
    }
  }

  /// The challenges currently shared on the backend, or `null` when offline.
  Future<List<Challenge>?> fetchChallenges(LiveConfig config) async {
    if (!canSync(config)) return null;
    try {
      final res = await _api.raw.get<Map<String, dynamic>>(
        _url(config, 'challenges'),
        queryParameters: _query(config),
      );
      final data = res.data;
      if (data == null) return const [];
      final out = <Challenge>[];
      data.forEach((id, value) {
        if (value is! Map) return;
        final json = {'id': id, ...value.map((k, v) => MapEntry('$k', v))};
        out.add(Challenge.fromJson(json));
      });
      out.sort((a, b) {
        final ca = a.createdAt;
        final cb = b.createdAt;
        if (ca == null || cb == null) return 0;
        return cb.compareTo(ca);
      });
      return out;
    } on DioException catch (e) {
      debugPrint('live: challenges unavailable (${e.type.name})');
      return null;
    } catch (e) {
      debugPrint('live: challenge parse failed ($e)');
      return null;
    }
  }

  /// Creates or replaces [challenge] on the backend.
  Future<bool> publishChallenge(Challenge challenge, LiveConfig config) async {
    if (!canSync(config)) return false;
    try {
      await _api.raw.put<void>(
        _url(config, 'challenges/${challenge.id}'),
        data: challenge.toJson(),
        queryParameters: _query(config),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('live: could not publish the challenge (${e.type.name})');
      return false;
    }
  }

  /// Records that [name] joined challenge [id].
  Future<bool> joinChallenge(
    String id, {
    required String name,
    required ChallengeStatus status,
    required LiveConfig config,
  }) async {
    if (!canSync(config)) return false;
    try {
      await _api.raw.patch<void>(
        _url(config, 'challenges/$id'),
        data: {'joinedBy': name, 'status': status.name},
        queryParameters: _query(config),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('live: could not join the challenge (${e.type.name})');
      return false;
    }
  }

  /// Sends a finished challenge's score back to the backend.
  Future<bool> publishResult(
    ChallengeResult result,
    String uid,
    LiveConfig config,
  ) async {
    if (!canSync(config)) return false;
    try {
      await _api.raw.put<void>(
        _url(config, 'results/${result.challengeId}/$uid'),
        data: result.toJson(),
        queryParameters: _query(config),
      );
      return true;
    } on DioException catch (e) {
      debugPrint('live: could not publish the result (${e.type.name})');
      return false;
    }
  }

  /// The ISO date of the Saturday that starts [date]'s week.
  static String weekKey(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = day.subtract(Duration(days: (day.weekday + 1) % 7));
    return '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
  }
}
