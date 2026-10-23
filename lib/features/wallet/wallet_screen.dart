/// The wallet: monthly allowance, commitments and expenses.
///
/// Shipped strings this screen is built from:
///   * `ميزانيتي`
///   * `ميزانيتي والتزاماتي`
///   * `حدد ميزانيتك الشهرية`
///   * `سجل المصروفات`
///   * `إضافة مصروف`
///   * `ابدأ بأول مصروف`
///   * `اتسجل {0} مصروف ✅`
///   * `أوفِ بوعد قطعته على نفسك`
///   * `دوس وعد`
///   * `إجمالي مصروفاتك`
///   * `رصيدك من مصروفك: {0}`
///   * `🔴 عديت الميزانية`
///   * `وعديت {0} من غير إجابة`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/wallet.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The wallet screen.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText('ميزانيتي')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _BalanceCard(
            wallet: wallet,
            onSetAllowance: () => _setAllowance(context, ref),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          SectionHeader(
            title: 'التزاماتي',
            icon: Icons.handshake_outlined,
            actionLabel: 'دوس وعد',
            onAction: () => _addCommitment(context, ref),
          ),
          if (wallet.commitments.isEmpty)
            const EmptyState(
              icon: Icons.handshake_outlined,
              title: 'أوفِ بوعد قطعته على نفسك',
              message: 'سجّل التزاماتك عشان تباقي ملتزم.',
            )
          else
            for (final c in wallet.commitments)
              _CommitmentTile(commitment: c),
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'سجل المصروفات',
            icon: Icons.receipt_long_outlined,
            actionLabel: 'إضافة مصروف',
            onAction: () => _addExpense(context, ref),
          ),
          if (wallet.expenses.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'ابدأ بأول مصروف',
              message: 'سجّل كام مصروف الأول وهنوريك بيروحوا فين.',
            )
          else
            for (final e in wallet.expenses)
              _ExpenseTile(expense: e),
        ],
      ),
    );
  }

  /// Sets the monthly allowance the balance card is measured against.
  void _setAllowance(BuildContext context, WidgetRef ref) {
    final wallet = ref.read(walletProvider);
    final amount = TextEditingController(
      text: wallet.allowance > 0 ? '${wallet.allowance}' : '',
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('حدد ميزانيتك الشهرية'),
        content: TextField(
          controller: amount,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'المبلغ الشهري'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(amount.text.trim()) ?? 0;
              if (value > 0) {
                ref.read(walletProvider.notifier).state = Wallet(
                  month: wallet.month,
                  allowance: value,
                  committed: wallet.committed,
                  commitments: wallet.commitments,
                  expenses: wallet.expenses,
                );
              }
              Navigator.of(context).pop();
            },
            child: const TrText('احفظ'),
          ),
        ],
      ),
    );
  }

  void _addExpense(BuildContext context, WidgetRef ref) {
    final category = TextEditingController();
    final amount = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('إضافة مصروف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: category,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'البند'),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'المبلغ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(amount.text.trim()) ?? 0;
              final label = category.text.trim();
              if (value > 0 && label.isNotEmpty) {
                final wallet = ref.read(walletProvider);
                ref.read(walletProvider.notifier).state = Wallet(
                  month: wallet.month,
                  allowance: wallet.allowance,
                  committed: wallet.committed,
                  commitments: wallet.commitments,
                  expenses: [
                    Expense(
                      date: DateTime.now(),
                      category: label,
                      amount: value,
                    ),
                    ...wallet.expenses,
                  ],
                );
              }
              Navigator.of(context).pop();
            },
            child: const TrText('ضيف'),
          ),
        ],
      ),
    );
  }

  void _addCommitment(BuildContext context, WidgetRef ref) {
    final label = TextEditingController();
    final amount = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('التزام جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'الوعد'),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'المبلغ'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(amount.text.trim()) ?? 0;
              final text = label.text.trim();
              if (value > 0 && text.isNotEmpty) {
                final wallet = ref.read(walletProvider);
                ref.read(walletProvider.notifier).state = Wallet(
                  month: wallet.month,
                  allowance: wallet.allowance,
                  committed: wallet.committed + value,
                  expenses: wallet.expenses,
                  commitments: [
                    Commitment(label: text, amount: value),
                    ...wallet.commitments,
                  ],
                );
              }
              Navigator.of(context).pop();
            },
            child: const TrText('ضيف'),
          ),
        ],
      ),
    );
  }
}

/// The balance header card.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.onSetAllowance});

  final Wallet wallet;
  final VoidCallback onSetAllowance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = wallet.spent > wallet.allowance && wallet.allowance > 0;

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, ZakerColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            'رصيدك من مصروفك: ${wallet.remaining}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'إجمالي مصروفاتك: ${wallet.spent}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(
            value: wallet.allowance == 0 ? 0 : wallet.spent / wallet.allowance,
            height: 8,
            color: over ? ZakerColors.danger : Colors.white,
            background: Colors.white24,
          ),
          if (over) ...[
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              '🔴 عديت الميزانية',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: ZakerSpacing.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            onPressed: onSetAllowance,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: TrText(
              wallet.allowance == 0
                  ? 'حدد ميزانيتك الشهرية'
                  : 'عدّل ميزانيتك: ${wallet.allowance}',
            ),
          ),
        ],
      ),
    );
  }
}

/// A single commitment row.
class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({required this.commitment});

  final Commitment commitment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: TrText(
                commitment.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TrText('${commitment.amount}', style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

/// A single expense row.
class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText(
                    expense.category,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TrText(
                    '${expense.date.year}/${expense.date.month}/${expense.date.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TrText('${expense.amount}', style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
