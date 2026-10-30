/// The files of one subject, grouped into week/day folders.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_access.dart';
import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/batches/resource_store.dart';
import '../../../core/theme.dart';
import '../../../models/batch.dart';
import '../../../models/batch_resource.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../batch_file_picker.dart';
import '../widgets/batch_labels.dart';
import '../widgets/resource_card.dart';

class SubjectResourcesScreen extends ConsumerStatefulWidget {
  const SubjectResourcesScreen({
    super.key,
    required this.batchId,
    required this.subjectId,
  });

  final String batchId;
  final String subjectId;

  @override
  ConsumerState<SubjectResourcesScreen> createState() =>
      _SubjectResourcesScreenState();
}

class _SubjectResourcesScreenState
    extends ConsumerState<SubjectResourcesScreen> {
  bool _busy = false;

  BatchSubject? _findSubject(BatchSnapshot snapshot) {
    for (final subject in snapshot.batch.subjects) {
      if (subject.id == widget.subjectId) return subject;
    }
    return null;
  }

  /// Mirrors the repository's upload gate so the button is never offered to
  /// someone the command surface would refuse.
  bool _canUpload(BatchSnapshot snapshot, String uid) {
    for (final member in snapshot.members) {
      if (member.uid != uid) continue;
      if (!BatchAccess.can(member.role, BatchAction.uploadResource)) {
        return false;
      }
      return !snapshot.batch.settings.uploadsAdminOnly ||
          member.role == BatchRole.owner ||
          member.role == BatchRole.admin;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final loaded = detail.valueOrNull;
    final subject = loaded == null ? null : _findSubject(loaded);
    final canUpload = loaded != null && _canUpload(loaded, uid);

    return Scaffold(
      appBar: AppBar(
        title: TrText(subject?.name ?? 'الملفات'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _showAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: const TrText('ضيف ملف'),
            )
          : null,
      body: detail.when(
        loading: () =>
            const Center(child: LoadingBox(label: 'بنحمّل ملفات المادة…')),
        error: (error, _) => _ResourcesError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(widget.batchId)),
        ),
        data: (snapshot) {
          final found = _findSubject(snapshot);
          if (found == null) {
            return const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'المادة مش موجودة',
              message: 'يمكن المادة اتمسحت من الدفعة.',
            );
          }
          final resources = [
            for (final item in snapshot.resources)
              if (item.subjectId == widget.subjectId) item,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (resources.isEmpty) {
            final canUpload = _canUpload(snapshot, uid);
            return EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'مفيش ملفات في المادة دي',
              message: canUpload
                  ? 'ضيف PDF أو تسجيل صوتي أو ملاحظة. الحاجات دي بتتخزن '
                      'على جهازك بس.'
                  : 'صاحب الدفعة لسه مضافش ملفات هنا.',
              action: canUpload
                  ? FilledButton.icon(
                      onPressed: _busy ? null : _showAddSheet,
                      icon: const Icon(Icons.add_rounded),
                      label: const TrText('ضيف ملف'),
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
            children: _buildGroups(resources, uid),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups(List<BatchResource> resources, String uid) {
    final ungrouped = [
      for (final item in resources)
        if (item.weekDay == null) item,
    ];
    final groups = <WeekDay, List<BatchResource>>{};
    for (final item in resources) {
      final weekDay = item.weekDay;
      if (weekDay == null) continue;
      groups.putIfAbsent(weekDay, () => []).add(item);
    }
    final keys = groups.keys.toList()
      ..sort(
        (a, b) => a.week == b.week
            ? a.day.compareTo(b.day)
            : a.week.compareTo(b.week),
      );
    return [
      for (final item in ungrouped) ...[
        ResourceCard(
          batchId: widget.batchId,
          resource: item,
          uid: uid,
        ),
        const SizedBox(height: ZakerSpacing.md),
      ],
      for (final key in keys) ...[
        _WeekDayFolder(
          batchId: widget.batchId,
          weekDay: key,
          resources: groups[key]!,
          uid: uid,
        ),
        const SizedBox(height: ZakerSpacing.md),
      ],
    ];
  }

  Future<void> _showAddSheet() async {
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                0,
                ZakerSpacing.lg,
                ZakerSpacing.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TrText(
                  'ضيف للمادة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const TrText('ملف PDF'),
              subtitle: const TrText('تقدر تختار أكتر من ملف في المرة.'),
              onTap: () => Navigator.of(sheetContext).pop(_AddChoice.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const TrText('تسجيل صوتي'),
              subtitle: const TrText('m4a أو aac أو mp3 أو wav أو ogg.'),
              onTap: () => Navigator.of(sheetContext).pop(_AddChoice.audio),
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const TrText('ملاحظة نصية'),
              subtitle: const TrText('عنوان ونص، من غير ملف.'),
              onTap: () => Navigator.of(sheetContext).pop(_AddChoice.note),
            ),
            const SizedBox(height: ZakerSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _AddChoice.pdf:
        await _import(ResourceKind.pdf);
      case _AddChoice.audio:
        await _import(ResourceKind.audio);
      case _AddChoice.note:
        await _addNote();
    }
  }

  Future<void> _import(ResourceKind kind) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final List<PickedResourceFile> picked;
    try {
      picked = await ref.read(batchFilePickerProvider)(kind);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: TrText('مقدرناش نفتح اختيار الملفات.')),
      );
      return;
    }
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final controller = ref.read(batchControllerProvider);
    var added = 0;
    String? firstError;
    for (final file in picked) {
      final path = file.path;
      if (path == null) {
        firstError ??= 'الملف مش متاح للقراءة.';
        continue;
      }
      try {
        await controller.importResource(
          batchId: widget.batchId,
          subjectId: widget.subjectId,
          kind: kind,
          sourcePath: path,
        );
        added += 1;
      } on BatchFailure catch (failure) {
        firstError ??= batchErrorText(failure);
      } on Object {
        firstError ??= 'حصل خطأ وإحنا بننسخ الملف.';
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (added) {
      0 => firstError ?? 'مفيش ملف اتضاف.',
      _ when added == picked.length => 'اتضاف ${arabicDigits(added)} ملف.',
      _ => 'اتضاف ${arabicDigits(added)} من '
          '${arabicDigits(picked.length)}. ${firstError ?? ''}',
    };
    messenger.showSnackBar(SnackBar(content: TrText(message.trim())));
  }

  Future<void> _addNote() async {
    if (_busy) return;
    final result = await showDialog<({String title, String note})>(
      context: context,
      builder: (dialogContext) => const _NoteDialog(),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(batchControllerProvider).addNote(
            batchId: widget.batchId,
            subjectId: widget.subjectId,
            title: result.title,
            note: result.note,
          );
      messenger.showSnackBar(
        const SnackBar(content: TrText('اتضافت الملاحظة.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: TrText('حصل خطأ وإحنا بنحفظ الملاحظة.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

enum _AddChoice { pdf, audio, note }

class _WeekDayFolder extends StatelessWidget {
  const _WeekDayFolder({
    required this.batchId,
    required this.weekDay,
    required this.resources,
    required this.uid,
  });

  final String batchId;
  final WeekDay weekDay;
  final List<BatchResource> resources;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
        title: TrText(
          weekDayLabel(weekDay.week, weekDay.day),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: TrText(
          '${arabicDigits(resources.length)} ملف',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          ZakerSpacing.md,
          0,
          ZakerSpacing.md,
          ZakerSpacing.md,
        ),
        children: [
          for (final resource in resources)
            Padding(
              padding: const EdgeInsets.only(top: ZakerSpacing.sm),
              child: ResourceCard(
                batchId: batchId,
                resource: resource,
                uid: uid,
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String? _titleError;
  String? _noteError;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();
    final titleError = title.isEmpty
        ? 'اكتب عنوان الملاحظة.'
        : title.runes.length > ResourceStore.maxTitleChars
            ? 'العنوان أطول من الحد.'
            : null;
    final noteError = note.isEmpty
        ? 'اكتب نص الملاحظة.'
        : note.runes.length > ResourceStore.maxNoteChars
            ? 'الملاحظة أطول من الحد.'
            : null;
    if (titleError != null || noteError != null) {
      setState(() {
        _titleError = titleError;
        _noteError = noteError;
      });
      return;
    }
    Navigator.of(context).pop((title: title, note: note));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TrText('ملاحظة جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'العنوان',
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: _noteController,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: 'نص الملاحظة',
                alignLabelWithHint: true,
                errorText: _noteError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const TrText('حفظ'),
        ),
      ],
    );
  }
}

class _ResourcesError extends StatelessWidget {
  const _ResourcesError({this.failure, required this.onRetry});

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
                  ? 'حصل خطأ وإحنا بنقرا ملفات المادة.'
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
