/// The question bank: the user's saved question banks and their types.
///
/// Shipped strings this screen is built from:
///   * `بنك الأسئلة`
///   * `بنك الأسئلة اللي في مكتبتك`
///   * `اختر مصدرك، وهنطلعلك بنك أسئلة بكل الأنواع تحله وتراجع بيه.`
///   * `اختر أنواع الأسئلة`
///   * `انواع الأسئلة` — the nine kinds the app generates:
///     `اسحب الكارت، وصل، رتب، صنف، واكتشف الغلط`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The nine question types the app can generate.
enum BankQuestionType {
  /// `اسحب` — swipe the card right for correct, left for wrong.
  swipe,

  /// `وصل` — match each item to its pair.
  match,

  /// `رتب` — put the items in the right order.
  order,

  /// `صنف` — sort the items into groups.
  classify,

  /// `اكتشف الغلط` — find the mistake.
  findError,

  /// `صنّف` — sort the terms into their buckets.
  bucket,

  /// `أكمل` — complete the sentence.
  fillBlank,

  /// `مقالي` — a written answer.
  written,

  /// `اختيار من متعدد` — pick one of several options.
  multipleChoice,
}

/// The banks the user has saved.
class QuestionBankScreen extends ConsumerWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(questionBanksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(ZakerStrings.s_9cfe0)), // بنك الأسئلة
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const SectionHeader(
            title: ZakerStrings.s_9cfe0,
            icon: Icons.quiz_rounded,
          ),
          Text(
            ZakerStrings.s_b96f7, // اختر مصدرك، وهنطلعلك بنك أسئلة…
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const _TypePicker(),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_d6b7e, // بنك الأسئلة اللي في مكتبتك
            icon: Icons.folder_rounded,
          ),
          if (banks.isEmpty)
            const EmptyState(
              icon: Icons.inbox_rounded,
              title: ZakerStrings.s_15130, // مكتبتك لسه فاضية
              message: ZakerStrings.s_4b5f7, // مفيش أسئلة اختيارات كفاية…
            )
          else
            for (final bank in banks) ...[
              _BankTile(bank: bank),
              const SizedBox(height: ZakerSpacing.sm),
            ],
        ],
      ),
    );
  }
}

/// The grid of question types the user can ask for.
class _TypePicker extends StatelessWidget {
  const _TypePicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: ZakerSpacing.sm,
      runSpacing: ZakerSpacing.sm,
      children: [
        for (final type in BankQuestionType.values)
          Chip(
            avatar: Icon(_iconFor(type), size: 16),
            label: Text(_labelFor(type)),
            labelStyle: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  String _labelFor(BankQuestionType type) => switch (type) {
    BankQuestionType.swipe => ZakerStrings.s_52ae0, // اسحب
    BankQuestionType.match => ZakerStrings.s_5e928, // وصل
    BankQuestionType.order => ZakerStrings.s_b91ff, // رتب
    BankQuestionType.classify => ZakerStrings.s_ecf49, // اشرح التحديد بالبلدي
    BankQuestionType.findError => ZakerStrings.s_c4ed3, // اكتشف الغلط
    BankQuestionType.bucket => ZakerStrings.s_3a759, // اختيار من متعدد…
    BankQuestionType.fillBlank => ZakerStrings.s_2b80e, // أكمل
    BankQuestionType.written => ZakerStrings.s_27981, // اختيارات وصح وغلط…
    BankQuestionType.multipleChoice => ZakerStrings.s_35ab5, // اختيار من متعدد…
  };

  IconData _iconFor(BankQuestionType type) => switch (type) {
    BankQuestionType.swipe => Icons.swipe_rounded,
    BankQuestionType.match => Icons.link_rounded,
    BankQuestionType.order => Icons.sort_rounded,
    BankQuestionType.classify => Icons.category_rounded,
    BankQuestionType.findError => Icons.search_rounded,
    BankQuestionType.bucket => Icons.dashboard_rounded,
    BankQuestionType.fillBlank => Icons.short_text_rounded,
    BankQuestionType.written => Icons.edit_note_rounded,
    BankQuestionType.multipleChoice => Icons.radio_button_checked_rounded,
  };
}

/// One saved bank.
class _BankTile extends StatelessWidget {
  const _BankTile({required this.bank});

  final QuestionBank bank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
            ),
            child: Icon(
              Icons.quiz_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bank.length} ${ZakerStrings.s_0120a}', // أسئلة التحدي
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
