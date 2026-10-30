/// Shared pieces of the local study-tool screens: the provenance badge, page
/// chips, the evidence quote and the missing-source state.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../widgets/batch_labels.dart';

/// Every generated artifact carries this line: it was built on the device
/// from the PDF's own text, not by a remote model.
class StudyLocalBadge extends StatelessWidget {
  const StudyLocalBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : ZakerSpacing.sm,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.memory_rounded,
            size: compact ? 12 : 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: TrText(
              'مولّد على الجهاز من نص الملف',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (compact
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `صفحة ٣` — the only page reference the tools ever show.
class StudyPageChip extends StatelessWidget {
  const StudyPageChip({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: TrText(
        'صفحة ${arabicDigits(page)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A verbatim quote from the cited page. The tools never show an answer
/// without it.
class StudyEvidenceCard extends StatelessWidget {
  const StudyEvidenceCard({
    super.key,
    required this.excerpt,
    required this.page,
  });

  final String excerpt;
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TrText(
                  'الدليل من نص الملف',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StudyPageChip(page: page),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            excerpt,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

/// Shown by the test, bank and map screens when the PDF was never extracted.
class StudyMissingSource extends StatelessWidget {
  const StudyMissingSource({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.document_scanner_outlined,
      title: 'الملف لسه ما اتحللش',
      message: 'افتح «أدوات الدراسة» من صفحة الملف واستخرج النص الأول. '
          'الاستخراج بيحصل على الجهاز.',
      action: FilledButton.icon(
        onPressed: () {
          if (context.canPop()) context.pop();
        },
        icon: const Icon(Icons.arrow_back_rounded),
        label: const TrText('رجوع للملف'),
      ),
    );
  }
}
