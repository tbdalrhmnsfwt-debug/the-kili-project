/// Wallet / budget models.
///
/// The shipped strings (`g_wallet`) describe a monthly allowance with dated
/// transactions, a committed amount, and zero or more expenses plus remaining.
library;

import 'dart:convert';

class Wallet {
  const Wallet({
    required this.month,
    this.allowance = 0,
    this.committed = 0,
    List<Expense>? expenses,
    List<Commitment>? commitments,
  }) : expenses = expenses ?? const <Expense>[],
       commitments = commitments ?? const <Commitment>[];

  final String month; // e.g. '2026-10'
  final int allowance;
  final int committed;
  final List<Expense> expenses;
  final List<Commitment> commitments;

  int get spent => expenses.fold<int>(0, (s, e) => s + e.amount);

  /// How much of the allowance is still unspent.
  int get remaining {
    final left = allowance - spent;
    return left < 0 ? 0 : left;
  }

  double get spendRate {
    final total = spent + committed;
    return total == 0 ? 0 : spent / total;
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'allowance': allowance,
        'committed': committed,
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'commitments': commitments.map((c) => c.toJson()).toList(),
      };

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final raw = (json['expenses'] as List?) ?? const [];
    final commitments = (json['commitments'] as List?) ?? const [];
    return Wallet(
      month: json['month'] as String? ?? '',
      allowance: (json['allowance'] as num?)?.toInt() ?? 0,
      committed: (json['committed'] as num?)?.toInt() ?? 0,
      expenses: raw
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      commitments: commitments
          .map((c) => Commitment.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// A single spending entry.
class Expense {
  const Expense({
    required this.date,
    required this.category,
    required this.amount,
    this.note = '',
  });

  final DateTime date;
  final String category;
  final int amount;
  final String note;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'category': category,
        'amount': amount,
        if (note.isNotEmpty) 'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        category: json['category'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
      );
}

/// A fixed-up commitment ("وعد"), e.g. "ادفع بقية".
class Commitment {
  const Commitment({required this.label, required this.amount});

  final String label;
  final int amount;

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};

  factory Commitment.fromJson(Map<String, dynamic> json) => Commitment(
        label: json['label'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
      );
}

/// Encodes [Wallet] to JSON for round-trip parsing.
String encodeWallet(Wallet w) => jsonEncode(w.toJson());

/// Decodes a wallet persisted by [encodeWallet].
Wallet decodeWallet(String raw) => Wallet.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
