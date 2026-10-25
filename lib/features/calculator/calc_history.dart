/// Persistent calculator history. Pure Dart so it can be verified without a
/// Flutter runtime.
library;

import 'dart:convert';

class CalcHistoryEntry {
  const CalcHistoryEntry({
    required this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
    this.exactResult,
    this.mode = 'COMP',
    this.angleUnit = 'DEG',
  });

  final String id;
  final String expression;
  final String result;
  final String? exactResult;
  final String mode;
  final String angleUnit;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'expression': expression,
    'result': result,
    if (exactResult != null) 'exact': exactResult,
    'mode': mode,
    'angle': angleUnit,
    'time': timestamp.toIso8601String(),
  };

  static CalcHistoryEntry? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final expression = value['expression'];
    final result = value['result'];
    if (expression is! String || result is! String || expression.isEmpty) {
      return null;
    }
    final timestamp = DateTime.tryParse(value['time'] is String ? value['time'] as String : '');
    return CalcHistoryEntry(
      id: value['id'] is String && (value['id'] as String).isNotEmpty
          ? value['id'] as String
          : '${timestamp?.microsecondsSinceEpoch ?? 0}-${expression.hashCode}',
      expression: expression,
      result: result,
      exactResult: value['exact'] is String ? value['exact'] as String : null,
      mode: value['mode'] is String ? value['mode'] as String : 'COMP',
      angleUnit: value['angle'] is String ? value['angle'] as String : 'DEG',
      timestamp: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CalcHistory {
  const CalcHistory._();

  static const int maximumEntries = 200;

  /// Encodes newest-first history, trimming to [maximumEntries].
  static String encode(List<CalcHistoryEntry> entries) {
    final trimmed = entries.take(maximumEntries).toList(growable: false);
    return jsonEncode(<Object?>[
      for (final entry in trimmed) entry.toJson(),
    ]);
  }

  /// Decodes JSON while ignoring corrupt rows instead of losing the whole
  /// history. The order is preserved.
  static List<CalcHistoryEntry> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <CalcHistoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CalcHistoryEntry>[];
      final entries = <CalcHistoryEntry>[];
      for (final value in decoded) {
        final entry = CalcHistoryEntry.tryFromJson(value);
        if (entry != null) entries.add(entry);
        if (entries.length >= maximumEntries) break;
      }
      return entries;
    } on FormatException {
      return <CalcHistoryEntry>[];
    }
  }

  /// Migrates the old `expression\u0001result` rows from earlier releases.
  static List<CalcHistoryEntry> fromLegacy(List<String> rows) {
    final entries = <CalcHistoryEntry>[];
    for (var i = 0; i < rows.length && i < maximumEntries; i++) {
      final row = rows[i];
      final split = row.indexOf('\u0001');
      if (split <= 0) continue;
      entries.add(
        CalcHistoryEntry(
          id: 'legacy-$i-${row.hashCode}',
          expression: row.substring(0, split),
          result: row.substring(split + 1),
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    return entries;
  }
}
