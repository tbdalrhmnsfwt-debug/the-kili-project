/// Small views shared by the timetable screens.
library;

import 'package:flutter/material.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';

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
