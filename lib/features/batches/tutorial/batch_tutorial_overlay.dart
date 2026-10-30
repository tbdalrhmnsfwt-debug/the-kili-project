/// The tour card and its destinations.
///
/// The card describes the current screen with words rather than drawing a
/// cutout around it: the local build has no reliable anchors across every
/// layout, so it does not pretend to highlight one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_repository.dart' show BatchSummary;
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../providers/batch_providers.dart';
import '../../../providers/tutorial_providers.dart';
import '../../../widgets/tr_text.dart';
import '../widgets/batch_labels.dart';
import 'batch_tutorial_steps.dart';

/// Where a tour step points, or null when no local screen exists.
String? batchTutorialLocation(String batchId, BatchTutorialTarget target) {
  return switch (target) {
    BatchTutorialTarget.none => null,
    BatchTutorialTarget.batches => ZakerRoutes.batches,
    BatchTutorialTarget.createBatch => ZakerRoutes.batchCreate,
    BatchTutorialTarget.joinBatch => ZakerRoutes.batchJoin,
    BatchTutorialTarget.hub =>
      batchId.isEmpty ? null : ZakerRoutes.batchHub(batchId),
    BatchTutorialTarget.subjects =>
      batchId.isEmpty ? null : ZakerRoutes.batchSubjects(batchId),
    BatchTutorialTarget.schedules =>
      batchId.isEmpty ? null : ZakerRoutes.batchSchedules(batchId),
    BatchTutorialTarget.updates =>
      batchId.isEmpty ? null : ZakerRoutes.batchUpdates(batchId),
    BatchTutorialTarget.exams =>
      batchId.isEmpty ? null : ZakerRoutes.batchExams(batchId),
    BatchTutorialTarget.admin =>
      batchId.isEmpty ? null : ZakerRoutes.batchAdmin(batchId),
  };
}

String? _openLabel(BatchTutorialTarget target) {
  return switch (target) {
    BatchTutorialTarget.createBatch => 'افتح إنشاء دفعة',
    BatchTutorialTarget.joinBatch => 'افتح الدخول بكود',
    BatchTutorialTarget.hub => 'افتح الدفعة',
    BatchTutorialTarget.subjects => 'افتح المواد',
    BatchTutorialTarget.schedules => 'افتح المواعيد',
    BatchTutorialTarget.updates => 'افتح المستجدات',
    BatchTutorialTarget.exams => 'افتح الامتحانات',
    BatchTutorialTarget.admin => 'افتح الإدارة',
    BatchTutorialTarget.none || BatchTutorialTarget.batches => null,
  };
}

/// Opens the tour card. [startStep] forces a step; otherwise the card
/// resumes an unfinished tour of the same mode and batch.
Future<void> showBatchTutorial(
  BuildContext context, {
  required BatchTutorialMode mode,
  String batchId = '',
  int? startStep,
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق الجولة',
    barrierColor: Colors.black54,
    transitionDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) {
      return BatchTutorialSheet(
        mode: mode,
        batchId: batchId,
        startStep: startStep,
        onOpenTarget: (target) {
          final location = batchTutorialLocation(batchId, target);
          Navigator.of(dialogContext).pop();
          if (location == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (target == BatchTutorialTarget.batches) {
              context.go(location);
            } else {
              context.push(location);
            }
          });
        },
      );
    },
    transitionBuilder: (context, animation, _, child) {
      if (reduceMotion) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Opens the tour from a list context: getting started when there is no
/// batch, the full tour for one batch, or a batch chooser for several.
Future<void> openBatchListTutorial(
  BuildContext context,
  WidgetRef ref,
) async {
  final available =
      (ref.read(batchListProvider).valueOrNull ?? const <BatchSummary>[])
          .where((item) => item.isAvailable)
          .toList();
  if (available.isEmpty) {
    await showBatchTutorial(
      context,
      mode: BatchTutorialMode.gettingStarted,
    );
    return;
  }
  if (available.length == 1) {
    await showBatchTutorial(
      context,
      mode: BatchTutorialMode.full,
      batchId: available.single.batchId,
    );
    return;
  }
  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          0,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
        ),
        children: [
          const TrText(
            'جولة على أنهي دفعة؟',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          for (final item in available)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_2_outlined),
              title: TrText(item.name),
              onTap: () => Navigator.of(sheetContext).pop(item.batchId),
            ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  await showBatchTutorial(
    context,
    mode: BatchTutorialMode.full,
    batchId: chosen,
  );
}

class BatchTutorialSheet extends ConsumerStatefulWidget {
  const BatchTutorialSheet({
    super.key,
    required this.mode,
    this.batchId = '',
    this.startStep,
    this.onOpenTarget,
  });

  final BatchTutorialMode mode;
  final String batchId;
  final int? startStep;
  final void Function(BatchTutorialTarget target)? onOpenTarget;

  @override
  ConsumerState<BatchTutorialSheet> createState() => _BatchTutorialSheetState();
}

class _BatchTutorialSheetState extends ConsumerState<BatchTutorialSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = ref.read(batchTutorialControllerProvider);
      final sameTour = saved.mode == widget.mode &&
          saved.batchId == widget.batchId &&
          !saved.completed;
      final step = widget.startStep ?? (sameTour ? saved.step : 1);
      ref.read(batchTutorialControllerProvider.notifier).begin(
            widget.mode,
            step: step,
            batchId: widget.batchId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(batchTutorialControllerProvider);
    final steps = tutorialStepsFor(widget.mode);
    final activeStep = progress.mode == widget.mode
        ? progress.step.clamp(1, steps.length)
        : (widget.startStep ?? 1).clamp(1, steps.length);
    final step = steps[activeStep - 1];
    final controller = ref.read(batchTutorialControllerProvider.notifier);
    final isLast = activeStep >= steps.length;
    final needsBatch = step.number >= 8 && widget.batchId.isEmpty;
    final openLabel = needsBatch ? null : _openLabel(step.target);
    final modeLabel = widget.mode == BatchTutorialMode.full
        ? 'الجولة الكاملة'
        : 'البداية السريعة';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: ZakerRadius.card,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(ZakerSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'جولة الدفعات: ${step.title}',
                            header: true,
                            child: TrText(
                              step.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق الجولة',
                          onPressed: () {
                            controller.close();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.xs),
                    TrText(
                      '$modeLabel • خطوة ${arabicDigits(activeStep)} '
                      'من ${arabicDigits(steps.length)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ZakerSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ZakerRadius.pill),
                      child: LinearProgressIndicator(
                        value: activeStep / steps.length,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    const SizedBox(height: ZakerSpacing.md),
                    TrText(
                      step.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                    ),
                    if (needsBatch) ...[
                      const SizedBox(height: ZakerSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(ZakerSpacing.md),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(ZakerRadius.sm),
                        ),
                        child: const TrText(
                          'الخطوات من ٨ محتاجة دفعة على الجهاز. اعمل دفعة '
                          'وارجع للجولة من أيقونة المساعدة عشان تكمّل من '
                          'هنا.',
                          style: TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                    const SizedBox(height: ZakerSpacing.lg),
                    Wrap(
                      spacing: ZakerSpacing.sm,
                      runSpacing: ZakerSpacing.sm,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            controller.close();
                            Navigator.of(context).pop();
                          },
                          child: const TrText('تخطي'),
                        ),
                        if (activeStep > 1)
                          OutlinedButton(
                            onPressed: controller.back,
                            child: const TrText('السابق'),
                          ),
                        if (openLabel != null && widget.onOpenTarget != null)
                          OutlinedButton(
                            onPressed: () {
                              controller.close();
                              widget.onOpenTarget!(step.target);
                            },
                            child: TrText(openLabel),
                          ),
                        if (needsBatch && widget.onOpenTarget != null)
                          OutlinedButton(
                            onPressed: () {
                              controller.close();
                              widget.onOpenTarget!(
                                  BatchTutorialTarget.createBatch);
                            },
                            child: const TrText('اعمل دفعة'),
                          ),
                        FilledButton(
                          onPressed: () {
                            if (isLast) {
                              controller.finish();
                              Navigator.of(context).pop();
                            } else {
                              controller.next();
                            }
                          },
                          child: TrText(isLast ? 'خلصت الجولة' : 'التالي'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
