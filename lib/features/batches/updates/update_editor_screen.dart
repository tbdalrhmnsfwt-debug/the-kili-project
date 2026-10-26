/// Writes or edits one local update.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/batch_update.dart';
import '../../../providers/update_providers.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_notice.dart';

class UpdateEditorScreen extends ConsumerStatefulWidget {
  const UpdateEditorScreen({
    super.key,
    required this.batchId,
    this.original,
  });

  final String batchId;

  /// Null when the post is new.
  final BatchUpdate? original;

  @override
  ConsumerState<UpdateEditorScreen> createState() => _UpdateEditorScreenState();
}

class _UpdateEditorScreenState extends ConsumerState<UpdateEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.original != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.original?.title ?? '');
    _body = TextEditingController(text: widget.original?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TrText(_editing ? 'تعديل المستجد' : 'مستجد جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.md,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          const BatchNotice(
            icon: Icons.phonelink_lock_rounded,
            text: 'المستجد بيتحفظ على الجهاز. إشعار فوري للأعضاء التانيين '
                'محتاج سيرفر.',
          ),
          const SizedBox(height: ZakerSpacing.lg),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              hintText: 'مثال: مراجعة يوم الخميس',
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'التفاصيل',
              hintText: 'اكتب التفاصيل اللي محتاج الأعضاء يعرفوها.',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: ZakerSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: TrText(_editing ? 'حفظ التعديل' : 'نشر المستجد'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'العنوان مطلوب.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(batchUpdatesControllerProvider);
      final original = widget.original;
      final saved = original == null
          ? await controller.publish(
              widget.batchId,
              title: title,
              body: _body.text,
            )
          : await controller.edit(
              widget.batchId,
              original.id,
              title: title,
              body: _body.text,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: TrText(_editing ? 'التعديل اتحفظ.' : 'المستجد اتنشر.'),
          ),
        );
      Navigator.of(context).pop(saved);
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (failure.field) {
          'title' => 'العنوان لازم يكون من حرف لـ ١٢٠ حرف.',
          'body' => 'التفاصيل أطول من الحد المسموح.',
          'updates' => 'عدد المستجدات وصل الحد. امسح مستجد قديم الأول.',
          _ => batchErrorText(failure),
        };
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'الحفظ ما تمّش. جرّب تاني.';
      });
    }
  }
}
