/// The create-batch form and its plain-language review step.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/batches/batch_failure.dart';
import '../../core/batches/local_batch_repository.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/batch.dart';
import '../../providers/app_providers.dart';
import '../../providers/batch_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'batch_error_text.dart';

class CreateBatchScreen extends ConsumerStatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  ConsumerState<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends ConsumerState<CreateBatchScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final List<String> _subjects = [];

  bool _uploadsAdminOnly = true;
  bool _requireApproval = true;
  bool _reviewing = false;
  bool _busy = false;

  String? _nameError;
  String? _subjectError;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider);
    final displayName = (user?.displayName ?? '').trim().isEmpty
        ? 'ضيف'
        : user!.displayName.trim();

    return Scaffold(
      appBar: AppBar(
        title: TrText(_reviewing ? 'مراجعة الدفعة' : 'دفعة جديدة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
          ZakerSpacing.xl,
        ),
        children: _reviewing
            ? _reviewContents(theme, displayName)
            : _formContents(theme),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            ZakerSpacing.sm,
            ZakerSpacing.lg,
            ZakerSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_reviewing) {
                            setState(() {
                              _reviewing = false;
                              _formError = null;
                            });
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                  child: TrText(_reviewing ? 'ارجع للتعديل' : 'إلغاء'),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : _reviewing
                          ? _create
                          : _review,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TrText(_reviewing ? 'أنشئ الدفعة' : 'كمّل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _formContents(ThemeData theme) {
    return [
      const SectionHeader(
        title: 'اسم الدفعة',
        icon: Icons.groups_2_outlined,
      ),
      TextField(
        controller: _name,
        maxLength: LocalBatchRepository.maxBatchNameLength,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'اسم الدفعة',
          hintText: 'مثال: دفعة تالتة ثانوي',
          errorText: _nameError,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_nameError != null) setState(() => _nameError = null);
        },
      ),
      const SizedBox(height: ZakerSpacing.md),
      const SectionHeader(
        title: 'المواد',
        icon: Icons.menu_book_rounded,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _subject,
              maxLength: LocalBatchRepository.maxSubjectNameLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'اسم المادة',
                errorText: _subjectError,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addSubject(),
              onChanged: (_) {
                if (_subjectError != null) {
                  setState(() => _subjectError = null);
                }
              },
            ),
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton.filledTonal(
              tooltip: 'ضيف المادة',
              onPressed: _busy ? null : _addSubject,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      TrText(
        '${_subjects.length} من ${LocalBatchRepository.maxSubjects} مواد. '
        'المواد اختيارية وتقدر تضيفها بعدين.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      if (_subjects.isNotEmpty) ...[
        const SizedBox(height: ZakerSpacing.sm),
        Wrap(
          spacing: ZakerSpacing.sm,
          runSpacing: ZakerSpacing.xs,
          children: [
            for (final subject in _subjects)
              InputChip(
                label: TrText(subject),
                onDeleted: _busy
                    ? null
                    : () => setState(() => _subjects.remove(subject)),
                deleteIcon: const Icon(Icons.close_rounded, size: 18),
              ),
          ],
        ),
      ],
      const SizedBox(height: ZakerSpacing.xl),
      const SectionHeader(
        title: 'إعدادات الدفعة',
        icon: Icons.tune_rounded,
      ),
      SwitchListTile.adaptive(
        value: _uploadsAdminOnly,
        onChanged:
            _busy ? null : (value) => setState(() => _uploadsAdminOnly = value),
        contentPadding: EdgeInsets.zero,
        title: const TrText('رفع الملفات للمسؤولين بس'),
        subtitle: const TrText(
          'لما تقفله، الأعضاء النشطين يقدروا يرفعوا. محليًا إنت العضو الوحيد.',
        ),
      ),
      SwitchListTile.adaptive(
        value: _requireApproval,
        onChanged:
            _busy ? null : (value) => setState(() => _requireApproval = value),
        contentPadding: EdgeInsets.zero,
        title: const TrText('موافقة على الانضمام'),
        subtitle: const TrText(
          'بيتحفظ مع الدفعة. الموافقة نفسها محتاجة سيرفر ومش متاحة هنا.',
        ),
      ),
      const SizedBox(height: ZakerSpacing.md),
      _LocalNote(
        text: 'مفيش رفع أو مزامنة. الدفعة وكل ملفاتها هتتحفظ على الجهاز ده.',
      ),
    ];
  }

  List<Widget> _reviewContents(ThemeData theme, String displayName) {
    final name = _name.text.trim();
    return [
      Container(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              'صاحب الدفعة: $displayName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: ZakerSpacing.xl),
            const TrText(
              'المواد',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            if (_subjects.isEmpty)
              const TrText('من غير مواد')
            else
              Wrap(
                spacing: ZakerSpacing.sm,
                runSpacing: ZakerSpacing.xs,
                children: [
                  for (final subject in _subjects) Chip(label: TrText(subject)),
                ],
              ),
            const Divider(height: ZakerSpacing.xl),
            _PolicyLine(
              icon: Icons.upload_file_rounded,
              text: _uploadsAdminOnly
                  ? 'رفع الملفات: المسؤولين بس.'
                  : 'رفع الملفات: كل الأعضاء النشطين.',
            ),
            const SizedBox(height: ZakerSpacing.sm),
            _PolicyLine(
              icon: Icons.how_to_reg_rounded,
              text: _requireApproval
                  ? 'الانضمام: بيحتاج موافقة المسؤول.'
                  : 'الانضمام: من غير موافقة.',
            ),
          ],
        ),
      ),
      const SizedBox(height: ZakerSpacing.md),
      _LocalNote(
        text: 'محليًا مفيش أعضاء تانيين ولا سيرفر، فالإعدادات بتتحفظ '
            'وبتتطبق على الدفعة من غير ما تتنفذ عبر أجهزة.',
      ),
      if (_formError != null) ...[
        const SizedBox(height: ZakerSpacing.md),
        _ErrorBanner(message: _formError!),
      ],
      const SizedBox(height: ZakerSpacing.md),
      const TrText(
        'لما تضغط «أنشئ الدفعة» هيتولّد كود دعوة من ٨ أرقام ويتحفظ كل حاجة '
        'على الجهاز. الكود ده مش تسجيل دخول.',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.5),
      ),
    ];
  }

  void _review() {
    final name = _name.text.trim();
    final nameError = _nameErrorFor(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }
    if (_subject.text.trim().isNotEmpty && !_addSubject()) return;
    setState(() {
      _nameError = null;
      _formError = null;
      _reviewing = true;
    });
  }

  String? _nameErrorFor(String name) {
    if (name.runes.length < 2) {
      return 'اسم الدفعة لازم يكون حرفين على الأقل.';
    }
    if (name.runes.length > LocalBatchRepository.maxBatchNameLength) {
      return 'اسم الدفعة أطول من ٦٠ حرف.';
    }
    if (_hasControl(name)) {
      return 'اسم الدفعة فيه رموز مش مسموحة.';
    }
    return null;
  }

  bool _addSubject() {
    final name = _subject.text.trim();
    if (name.isEmpty) {
      setState(() => _subjectError = 'اكتب اسم المادة الأول.');
      return false;
    }
    if (name.runes.length > LocalBatchRepository.maxSubjectNameLength) {
      setState(() => _subjectError = 'اسم المادة أطول من 40 حرف.');
      return false;
    }
    if (_hasControl(name)) {
      setState(() => _subjectError = 'اسم المادة فيه رموز مش مسموحة.');
      return false;
    }
    if (_subjects.length >= LocalBatchRepository.maxSubjects) {
      setState(() => _subjectError = 'الحد الأقصى 30 مادة.');
      return false;
    }
    final key = _subjectKey(name);
    if (_subjects.any((subject) => _subjectKey(subject) == key)) {
      setState(() => _subjectError = 'المادة دي موجودة بالفعل.');
      return false;
    }
    setState(() {
      _subjects.add(name);
      _subject.clear();
      _subjectError = null;
    });
    return true;
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final nameError = _nameErrorFor(name);
    if (nameError != null) {
      setState(() {
        _nameError = nameError;
        _reviewing = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final user = ref.read(authUserProvider);
      final batch = await ref.read(batchControllerProvider).createBatch(
            name: name,
            subjects: List<String>.of(_subjects),
            displayName: user?.displayName ?? '',
            settings: BatchSettings(
              uploadsAdminOnly: _uploadsAdminOnly,
              requireApproval: _requireApproval,
            ),
          );
      if (!mounted) return;
      context.pushReplacement(ZakerRoutes.batchCreated(batch.id));
    } on BatchFailure catch (failure) {
      if (mounted) setState(() => _formError = batchErrorText(failure));
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'الدفعة ما اتعملتش. جرّب تاني.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _subjectKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _hasControl(String value) =>
      value.runes.any((rune) => rune < 0x20 || rune == 0x7F);
}

class _PolicyLine extends StatelessWidget {
  const _PolicyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: ZakerSpacing.sm),
        Expanded(
          child: TrText(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _LocalNote extends StatelessWidget {
  const _LocalNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: ZakerRadius.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phonelink_lock_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: ZakerRadius.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
