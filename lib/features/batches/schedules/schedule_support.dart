/// Small views shared by the timetable screens.
library;

import 'package:flutter/material.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';

/// One honest line about the schedule, on a tinted local surface.
class ScheduleBanner extends StatelessWidget {
  const ScheduleBanner({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A failure while reading the timetable, with one retry action.
class ScheduleErrorView extends StatelessWidget {
  const ScheduleErrorView({super.key, this.failure, required this.onRetry});

  final BatchFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.sync_problem_rounded,
      title: 'مقدرناش نقرا الجدول',
      message: failure == null
          ? 'حصل خطأ مش معروف. جرّب تفتح الصفحة تاني.'
          : batchErrorText(failure!),
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const TrText('جرّب تاني'),
      ),
    );
  }
}
