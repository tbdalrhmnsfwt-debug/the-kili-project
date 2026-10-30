/// The subjects inside one batch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../models/batch.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import '../widgets/storage_usage_line.dart';
import 'subject_dialogs.dart';

class BatchSubjectsScreen extends ConsumerWidget {
  const BatchSubjectsScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final isOwner =
        detail.valueOrNull != null && detail.valueOrNull!.batch.ownerUid == uid;

    return Scaffold(
      appBar: AppBar(title: const TrText('المواد')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _addSubject(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const TrText('مادة جديدة'),
            )
          : null,
      body: detail.when(
        loading: () => const Center(child: LoadingBox(label: 'بنحمّل المواد…')),
        error: (error, _) => _SubjectsError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
        data: (snapshot) => _SubjectsBody(
          batchId: batchId,
          snapshot: snapshot,
          uid: uid,
        ),
      ),
    );
  }

  Future<void> _addSubject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await promptSubjectName(
      context,
      title: 'مادة جديدة',
      confirmLabel: 'ضيف',
    );
    if (name == null) return;
    try {
      await ref.read(batchControllerProvider).addSubject(batchId, name);
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

class _SubjectsBody extends ConsumerWidget {
  const _SubjectsBody({
    required this.batchId,
    required this.snapshot,
    required this.uid,
  });

  final String batchId;
  final BatchSnapshot snapshot;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = [...snapshot.batch.subjects]
      ..sort((a, b) => a.order.compareTo(b.order));
    final isOwner = snapshot.batch.ownerUid == uid;
    if (subjects.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'مفيش مواد',
        message: isOwner
            ? 'ضيف أول مادة عشان ترتّب فيها الملفات والملاحظات. '
                'كل ملف لازم يكون جوه مادة.'
            : 'صاحب الدفعة لسه مضافش مواد.',
        action: isOwner
            ? FilledButton.icon(
                onPressed: () => _addSubject(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const TrText('ضيف مادة'),
              )
            : null,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        96,
      ),
      children: [
        StorageUsageLine(batchId: batchId),
        const SizedBox(height: ZakerSpacing.md),
        for (final subject in subjects) ...[
          _SubjectCard(
            batchId: batchId,
            subject: subject,
            resourceCount: snapshot.resources
                .where((item) => item.subjectId == subject.id)
                .length,
            isOwner: isOwner,
            snapshot: snapshot,
          ),
          const SizedBox(height: ZakerSpacing.md),
        ],
      ],
    );
  }

  Future<void> _addSubject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await promptSubjectName(
      context,
      title: 'مادة جديدة',
      confirmLabel: 'ضيف',
    );
    if (name == null) return;
    try {
      await ref.read(batchControllerProvider).addSubject(batchId, name);
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({
    required this.batchId,
    required this.subject,
    required this.resourceCount,
    required this.isOwner,
    required this.snapshot,
  });

  final String batchId;
  final BatchSubject subject;
  final int resourceCount;
  final bool isOwner;
  final BatchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          ZakerRoutes.batchSubjectResources(batchId, subject.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.folder_copy_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      resourceCount == 0
                          ? 'مفيش ملفات'
                          : '${arabicDigits(resourceCount)} ملف',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  tooltip: 'خيارات المادة',
                  onSelected: (value) {
                    if (value == 'rename') _rename(context, ref);
                    if (value == 'delete') _delete(context, ref);
                  },
                  itemBuilder: (menuContext) => const [
                    PopupMenuItem(
                        value: 'rename', child: TrText('تعديل الاسم')),
                    PopupMenuItem(value: 'delete', child: TrText('حذف المادة')),
                  ],
                )
              else
                Icon(
                  Icons.chevron_left_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await promptSubjectName(
      context,
      title: 'تعديل اسم المادة',
      confirmLabel: 'حفظ',
      initialName: subject.name,
    );
    if (name == null || name == subject.name) return;
    try {
      await ref
          .read(batchControllerProvider)
          .renameSubject(batchId, subject.id, name);
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final others = [
      for (final item in snapshot.batch.subjects)
        if (item.id != subject.id) item,
    ]..sort((a, b) => a.order.compareTo(b.order));
    final choice = await promptSubjectDelete(
      context,
      subject: subject,
      resourceCount: resourceCount,
      otherSubjects: others,
    );
    if (choice == null) return;
    try {
      await ref.read(batchControllerProvider).deleteSubject(
            batchId,
            subject.id,
            moveToSubjectId: choice.moveToSubjectId,
            deleteResources: choice.deleteResources,
          );
      messenger.showSnackBar(
        SnackBar(
          content: TrText(
            choice.deleteResources && resourceCount > 0
                ? 'اتمسحت المادة و${arabicDigits(resourceCount)} ملف.'
                : 'اتمسحت المادة.',
          ),
        ),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

class _SubjectsError extends StatelessWidget {
  const _SubjectsError({this.failure, required this.onRetry});

  final BatchFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              failure == null
                  ? 'حصل خطأ وإحنا بنقرا مواد الدفعة.'
                  : batchErrorText(failure!),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZakerSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('جرّب تاني'),
            ),
          ],
        ),
      ),
    );
  }
}
