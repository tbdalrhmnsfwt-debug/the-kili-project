/// Invitation-code generation, normalisation, hashing and guess throttling.
///
/// The code is discovery, not authentication: it only finds a batch that
/// already exists on this device. It is never logged and only its SHA-256
/// hash is kept in the used-code ledger.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'batch_failure.dart';

class BatchCodeService {
  BatchCodeService({Random? random}) : _random = random;

  final Random? _random;

  /// Generates a code that is not in [taken].
  ///
  /// Throws [BatchFailure] only when [maxAttempts] generated codes all
  /// collided, which is effectively impossible with a 10^8 space.
  String generateUnique({required Set<String> taken, int maxAttempts = 64}) {
    return generateUniqueWhere(
      isTaken: taken.contains,
      maxAttempts: maxAttempts,
    );
  }

  /// Generates a code for which [isTaken] is false.
  ///
  /// The ledger stores hashes, so repositories pass a predicate that hashes
  /// the candidate rather than a set of raw codes.
  String generateUniqueWhere({
    required bool Function(String code) isTaken,
    int maxAttempts = 64,
  }) {
    final random = _random ?? Random.secure();
    for (var i = 0; i < maxAttempts; i++) {
      final code = random.nextInt(100000000).toString().padLeft(8, '0');
      if (!isTaken(code)) return code;
    }
    throw const BatchFailure(
      BatchFailureCode.validationFailed,
      field: 'code',
      detail: 'code space exhausted',
    );
  }

  /// Turns user input into the canonical eight digits, or null when it is not
  /// a complete code.
  ///
  /// Arabic-Indic (٠–٩) and Extended Arabic-Indic (۰–۹) digits are accepted,
  /// as are spaces and dashes between digits. A leading zero is preserved.
  static String? normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune);
      } else if (_isSeparator(rune)) {
        continue;
      } else {
        return null;
      }
    }
    final code = buffer.toString();
    return code.length == 8 ? code : null;
  }

  /// The digits of [input] in Latin form, dropping separators and anything
  /// that is not a digit. Used by the grouping input formatter while the field
  /// is still incomplete; [normalize] remains the validating entry point.
  static String digitsOnly(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final digit = _digitFor(rune);
      if (digit != null) buffer.writeCharCode(digit);
    }
    return buffer.toString();
  }

  /// Groups a complete code as `1234 5678`; returns [code] unchanged when it
  /// is not a complete code.
  static String format(String code) {
    final normalized = normalize(code);
    if (normalized == null) return code;
    return '${normalized.substring(0, 4)} ${normalized.substring(4)}';
  }

  static int? _digitFor(int rune) {
    if (rune >= 0x0660 && rune <= 0x0669) return 0x30 + rune - 0x0660;
    if (rune >= 0x06F0 && rune <= 0x06F9) return 0x30 + rune - 0x06F0;
    if (rune >= 0x30 && rune <= 0x39) return rune;
    return null;
  }

  static bool _isSeparator(int rune) =>
      rune == 0x20 || // space
      rune == 0x09 || // tab
      rune == 0x0A || // newline
      rune == 0x0D || // carriage return
      rune == 0x2010 || // hyphen
      rune == 0x2013 || // en dash
      rune == 0x2014 || // em dash
      rune == 0x200E || // left-to-right mark
      rune == 0x200F || // right-to-left mark
      rune == 0x2D; // hyphen-minus

  /// Whether [input] resolves to [expected].
  static bool matches(String input, String expected) {
    final a = normalize(input);
    final b = normalize(expected);
    return a != null && b != null && a == b;
  }

  /// The ledger value for a code. Never store or log the code itself.
  static String codeHash(String code) {
    final normalized = normalize(code);
    if (normalized == null) {
      throw const BatchFailure(BatchFailureCode.invalidCode, field: 'code');
    }
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}

/// Limits repeated wrong-code attempts on one device.
///
/// A failure is counted only when it happened inside [window]. After
/// [freeAttempts] failures the guard locks for [baseCooldown]; each further
/// block doubles the wait, capped at [maxCooldown]. A successful resolution
/// calls [reset]. The guard is a usability measure, not a security boundary.
class CodeAttemptGuard {
  CodeAttemptGuard({
    this.freeAttempts = 5,
    this.window = const Duration(minutes: 10),
    this.baseCooldown = const Duration(seconds: 60),
    this.maxCooldown = const Duration(minutes: 10),
    DateTime Function()? clock,
    List<DateTime> failures = const [],
    int blocks = 0,
    DateTime? lockedUntil,
  })  : _clock = clock ?? DateTime.now,
        _failures = [...failures],
        _blocks = blocks,
        _lockedUntil = lockedUntil,
        assert(freeAttempts > 0) {
    _prune(_clock());
  }

  final int freeAttempts;
  final Duration window;
  final Duration baseCooldown;
  final Duration maxCooldown;
  final DateTime Function() _clock;

  final List<DateTime> _failures;
  int _blocks;
  DateTime? _lockedUntil;

  int get failures => _failures.length;
  int get blocks => _blocks;

  bool canAttempt([DateTime? now]) {
    final locked = _lockedUntil;
    if (locked == null) return true;
    return !(now ?? _clock()).isBefore(locked);
  }

  /// Time left before another attempt is allowed.
  Duration remaining([DateTime? now]) {
    final locked = _lockedUntil;
    if (locked == null) return Duration.zero;
    final left = locked.difference(now ?? _clock());
    return left.isNegative ? Duration.zero : left;
  }

  void recordFailure([DateTime? now]) {
    final at = now ?? _clock();
    _prune(at);
    _failures.add(at);
    if (_failures.length < freeAttempts) return;
    _failures.clear();
    final duration = _cooldownFor(_blocks);
    _lockedUntil = at.add(duration);
    _blocks++;
  }

  void reset() {
    _failures.clear();
    _blocks = 0;
    _lockedUntil = null;
  }

  /// The state to persist. Only timestamps and counters, never the code.
  Map<String, dynamic> toJson() {
    final now = _clock();
    _prune(now);
    return {
      'failures': [
        for (final failure in _failures) failure.toUtc().toIso8601String(),
      ],
      'blocks': _blocks,
      if (_lockedUntil != null)
        'lockedUntil': _lockedUntil!.toUtc().toIso8601String(),
    };
  }

  /// Restores a persisted state, ignoring malformed entries.
  factory CodeAttemptGuard.fromJson(
    Map<String, dynamic> json, {
    DateTime Function()? clock,
    int freeAttempts = 5,
    Duration window = const Duration(minutes: 10),
    Duration baseCooldown = const Duration(seconds: 60),
    Duration maxCooldown = const Duration(minutes: 10),
  }) {
    final failures = <DateTime>[];
    final rawFailures = json['failures'];
    if (rawFailures is List) {
      for (final raw in rawFailures) {
        if (raw is! String) continue;
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) failures.add(parsed.toLocal());
      }
    }
    final blocks = (json['blocks'] as num?)?.toInt() ?? 0;
    final lockedUntil = DateTime.tryParse(
      json['lockedUntil'] as String? ?? '',
    )?.toLocal();
    return CodeAttemptGuard(
      freeAttempts: freeAttempts,
      window: window,
      baseCooldown: baseCooldown,
      maxCooldown: maxCooldown,
      clock: clock,
      failures: failures,
      blocks: blocks < 0 ? 0 : blocks,
      lockedUntil: lockedUntil,
    );
  }

  void _prune(DateTime now) {
    _failures.removeWhere((failure) => now.difference(failure) > window);
  }

  Duration _cooldownFor(int block) {
    final shifts = block.clamp(0, 10).toInt();
    final millis = baseCooldown.inMilliseconds * (1 << shifts);
    return Duration(
      milliseconds: millis.clamp(0, maxCooldown.inMilliseconds).toInt(),
    );
  }
}

/// Generates and hashes a code, kept as one call for the repository.
String generateInviteCode({required Set<String> taken, Random? random}) {
  return BatchCodeService(random: random).generateUnique(taken: taken);
}
