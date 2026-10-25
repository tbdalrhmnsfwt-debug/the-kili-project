/// Dialogs for naming a subject and for deleting one that has resources.
library;

import 'package:flutter/material.dart';

import '../../../models/batch.dart';
import '../../../widgets/tr_text.dart';
import '../widgets/batch_labels.dart';

/// Asks for a subject name. Returns the trimmed name, or null on cancel.
Future<String?> promptSubjectName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _SubjectNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
    ),
  );
}

class _SubjectNameDialog extends StatefulWidget {
  const _SubjectNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialName,
  });

  final String title;
  final String confirmLabel;
  final String? initialName;

  @override
  State<_SubjectNameDialog> createState() => _SubjectNameDialogState();
}

class _SubjectNameDialogState extends State<_SubjectNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم المادة.');
      return;
    }
    if (name.runes.length > 40) {
      setState(() => _error = 'اسم المادة أطول من 40 حرف.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TrText(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'اسم المادة',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: TrText(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// What to do with a deleted subject's resources.
class SubjectDeleteChoice {
  const SubjectDeleteChoice.move(String this.moveToSubjectId)
      : deleteResources = false;

  const SubjectDeleteChoice.deleteAll()
      : moveToSubjectId = null,
        deleteResources = true;

  /// A subject with no resources: there is nothing to move or delete.
  const SubjectDeleteChoice.noResources()
      : moveToSubjectId = null,
        deleteResources = false;

  /// Move the resources here first; null when they are deleted.
  final String? moveToSubjectId;
  final bool deleteResources;
}

/// Confirms deleting a subject.
///
/// A subject that still has resources cannot be deleted on its own: the owner
/// either moves them to another subject or deletes them with a visible count.
/// With no other subject, only delete and cancel are offered.
Future<SubjectDeleteChoice?> promptSubjectDelete(
  BuildContext context, {
  required BatchSubject subject,
  required int resourceCount,
  required List<BatchSubject> otherSubjects,
}) {
  return showDialog<SubjectDeleteChoice>(
    context: context,
    builder: (dialogContext) => _SubjectDeleteDialog(
      subject: subject,
      resourceCount: resourceCount,
      otherSubjects: otherSubjects,
    ),
  );
}

class _SubjectDeleteDialog extends StatefulWidget {
  const _SubjectDeleteDialog({
    required this.subject,
    required this.resourceCount,
    required this.otherSubjects,
  });

  final BatchSubject subject;
  final int resourceCount;
  final List<BatchSubject> otherSubjects;

  @override
  State<_SubjectDeleteDialog> createState() => _SubjectDeleteDialogState();
}

class _SubjectDeleteDialogState extends State<_SubjectDeleteDialog> {
  String? _moveToSubjectId;
  bool _deleteResources = false;

  bool get _needsChoice => widget.resourceCount > 0;

  SubjectDeleteChoice _choice() {
    if (!_needsChoice) return const SubjectDeleteChoice.noResources();
    if (_deleteResources) return const SubjectDeleteChoice.deleteAll();
    return SubjectDeleteChoice.move(_moveToSubjectId!);
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.otherSubjects;
    final canMove = _needsChoice && others.isNotEmpty;
    final confirmed = !_needsChoice ||
        _deleteResources ||
        (canMove && _moveToSubjectId != null);
    return AlertDialog(
      title: const TrText('حذف المادة؟'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TrText(
              _needsChoice
                  ? '«${widget.subject.name}» فيها '
                      '${arabicDigits(widget.resourceCount)} ملف. '
                      'اختار تنقلهم لمادة تانية أو تمسحهم مع المادة.'
                  : 'هيتم حذف «${widget.subject.name}» من الدفعة. '
                      'مفيش ملفات جواها.',
            ),
            if (canMove) ...[
              const SizedBox(height: 8),
              for (final other in others)
                _ChoiceRow(
                  label: 'انقلها لـ ${other.name}',
                  selected: !_deleteResources && _moveToSubjectId == other.id,
                  onTap: () => setState(() {
                    _moveToSubjectId = other.id;
                    _deleteResources = false;
                  }),
                ),
              _ChoiceRow(
                label: 'امسح الملفات (${arabicDigits(widget.resourceCount)})',
                selected: _deleteResources,
                onTap: () => setState(() {
                  _deleteResources = true;
                  _moveToSubjectId = null;
                }),
              ),
            ] else if (_needsChoice) ...[
              const SizedBox(height: 8),
              const TrText(
                'مفيش مادة تانية تنقلها، فمسح المادة هيمسح الملفات كمان.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed:
              confirmed ? () => Navigator.of(context).pop(_choice()) : null,
          child: const TrText('حذف المادة'),
        ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(child: TrText(label)),
            ],
          ),
        ),
      ),
    );
  }
}
