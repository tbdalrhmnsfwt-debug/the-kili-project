/// Definitions, dates, numbers and steps extracted from one PDF, each with
/// the sentence and page it came from, plus a local search box.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/study_source.dart';
import '../../../providers/study_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import 'study_widgets.dart';

class InformationBankScreen extends ConsumerStatefulWidget {
  const InformationBankScreen({
    super.key,
    required this.batchId,
    required this.resourceId,
  });

  final String batchId;
  final String resourceId;

  @override
  ConsumerState<InformationBankScreen> createState() =>
      _InformationBankScreenState();
}

class _InformationBankScreenState extends ConsumerState<InformationBankScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = (batchId: widget.batchId, resourceId: widget.resourceId);
    final document = ref.watch(studyDocumentProvider(args));

    return Scaffold(
      appBar: AppBar(title: const TrText('بنك المعلومات')),
      body: document.when(
        loading: () =>
            const Center(child: LoadingBox(label: 'بنقرا النص المحفوظ…')),
        error: (error, _) => _BankError(
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'مقدرناش نقرا النص المحفوظ.',
          onRetry: () {
            ref.invalidate(studyDocumentProvider(args));
            ref.invalidate(studyBankProvider(args));
          },
        ),
        data: (document) {
          if (document == null) return const StudyMissingSource();
          final bank = ref.watch(studyBankProvider(args));
          return bank.when(
            loading: () =>
                const Center(child: LoadingBox(label: 'بنجهّز بنك المعلومات…')),
            error: (error, _) => _BankError(
              message: error is BatchFailure
                  ? batchErrorText(error)
                  : 'مقدرناش نجهّز بنك المعلومات.',
              onRetry: () => ref.invalidate(studyBankProvider(args)),
            ),
            data: (bank) {
              if (bank == null || bank.isEmpty) {
                return EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'مفيش معلومات كفاية',
                  message: 'النص المستخرج من الملف مفيهوش تعريفات أو تواريخ '
                      'أو أرقام أو خطوات واضحة.',
                  action: FilledButton.icon(
                    onPressed: () {
                      if (context.canPop()) context.pop();
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const TrText('رجوع'),
                  ),
                );
              }
              final facts = bank.matching(studySearchNormalizer, _query);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZakerSpacing.lg,
                      ZakerSpacing.md,
                      ZakerSpacing.lg,
                      ZakerSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'دوّر في المعلومات…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح البحث',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: ZakerSpacing.sm),
                        const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StudyLocalBadge(compact: true),
                        ),
                        const SizedBox(height: 2),
                        TrText(
                          '${arabicDigits(facts.length)} من '
                          '${arabicDigits(bank.facts.length)}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: facts.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'مفيش نتايج',
                            message: 'البحث بيشتغل على النص المستخرج من '
                                'الملف. جرّب كلمة تانية أو امسح البحث.',
                            action: TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: const TrText('امسح البحث'),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              ZakerSpacing.lg,
                              ZakerSpacing.sm,
                              ZakerSpacing.lg,
                              ZakerSpacing.xxl,
                            ),
                            itemCount: facts.length,
                            separatorBuilder: (_, __) => const SizedBox(
                              height: ZakerSpacing.sm,
                            ),
                            itemBuilder: (context, index) => _FactTile(
                              fact: facts[index],
                              onTap: () => _showFact(facts[index]),
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showFact(StudyFact fact) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            0,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _factIcon(fact.kind),
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TrText(
                        _factLabel(fact.kind),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    StudyPageChip(page: fact.page),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.md),
                if (fact.term.isNotEmpty) ...[
                  TrText(
                    fact.term,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: ZakerSpacing.sm),
                ],
                TrText(
                  fact.text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.6),
                ),
                const SizedBox(height: ZakerSpacing.md),
                StudyEvidenceCard(excerpt: fact.excerpt, page: fact.page),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact, required this.onTap});

  final StudyFact fact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: ZakerRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _factIcon(fact.kind),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TrText(
                      _factLabel(fact.kind),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StudyPageChip(page: fact.page),
                ],
              ),
              const SizedBox(height: ZakerSpacing.sm),
              if (fact.term.isNotEmpty) ...[
                TrText(
                  fact.term,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              TrText(
                fact.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankError extends StatelessWidget {
  const _BankError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'مقدرناش نجهّز بنك المعلومات',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const TrText('جرّب تاني'),
      ),
    );
  }
}

String _factLabel(StudyFactKind kind) => switch (kind) {
      StudyFactKind.definition => 'تعريف',
      StudyFactKind.date => 'تاريخ',
      StudyFactKind.number => 'رقم',
      StudyFactKind.step => 'خطوة',
    };

IconData _factIcon(StudyFactKind kind) => switch (kind) {
      StudyFactKind.definition => Icons.book_outlined,
      StudyFactKind.date => Icons.event_outlined,
      StudyFactKind.number => Icons.numbers_rounded,
      StudyFactKind.step => Icons.format_list_numbered_rounded,
    };
