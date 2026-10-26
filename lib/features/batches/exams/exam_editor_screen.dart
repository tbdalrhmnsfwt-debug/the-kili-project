/// Authoring one exam: questions, availability and publishing.
///
/// The editor validates before writing and the repository validates again. A
/// published exam is never rewritten here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/batch_exam.dart';
import '../../../models/batch_resource.dart';
import '../../../models/exam.dart';
import '../../../models/study_source.dart';
import '../../../providers/batch_providers.dart';
import '../../../providers/exam_providers.dart';
import '../../../providers/study_providers.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import '../widgets/batch_notice.dart';
import 'exam_support.dart';

class ExamEditorScreen extends ConsumerStatefulWidget {
  const ExamEditorScreen({super.key, required this.batchId, this.original});

  final String batchId;
  final BatchExam? original;

  @override
  ConsumerState<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends ConsumerState<ExamEditorScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _minutes = TextEditingController();
  final _maxAttempts = TextEditingController(text: '3');
  final List<_QuestionDraft> _questions = [];

  String _subjectId = '';
  DateTime? _opensAt;
  DateTime? _closesAt;
  BatchExamResultsMode _resultsMode = BatchExamResultsMode.immediately;
  BatchExamAttemptPolicy _attemptPolicy = BatchExamAttemptPolicy.single;
  String? _error;
  bool _busy = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    if (original != null) {
      _title.text = original.title;
      _description.text = original.description;
      _minutes.text =
          original.durationMinutes > 0 ? '${original.durationMinutes}' : '';
      _subjectId = original.subjectId;
      _opensAt = original.opensAt;
      _closesAt = original.closesAt;
      _resultsMode = original.resultsMode;
      _attemptPolicy = original.attemptPolicy;
      if (original.attemptPolicy == BatchExamAttemptPolicy.limited) {
        _maxAttempts.text = '${original.maxAttempts}';
      }
      for (final question in original.questions) {
        _questions.add(_QuestionDraft.fromQuestion(question));
      }
    }
    if (_questions.isEmpty) _questions.add(_QuestionDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _minutes.dispose();
    _maxAttempts.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final snapshot = detail.valueOrNull;
    final pdfs = [
      for (final resource in snapshot?.resources ?? const <BatchResource>[])
        if (resource.kind == ResourceKind.pdf) resource,
    ];
    final isEditing = widget.original != null;

    return Scaffold(
      appBar: AppBar(
        title: TrText(isEditing ? 'تعديل الامتحان' : 'امتحان جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.md,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          BatchNotice(
            icon: Icons.phonelink_lock_rounded,
            text: _generating
                ? 'بنولّد الأسئلة من نص الملف على الجهاز…'
                : 'الامتحان بيتحفظ على الجهاز. التوليد من ملف بيشتغل محليًا '
                    'من نص الملف، مش من سيرفر.',
          ),
          if (_error != null) ...[
            const SizedBox(height: ZakerSpacing.md),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: ZakerSpacing.md),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'عنوان الامتحان',
              hintText: 'مثال: مراجعة الفصل الأول',
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'تعليمات للطلبة',
              hintText: 'اختياري',
              alignLabelWithHint: true,
            ),
          ),
          if ((snapshot?.batch.subjects ?? const []).isNotEmpty) ...[
            const SizedBox(height: ZakerSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              decoration: const InputDecoration(labelText: 'المادة'),
              items: [
                const DropdownMenuItem(value: '', child: TrText('من غير مادة')),
                for (final subject in snapshot!.batch.subjects)
                  DropdownMenuItem(
                    value: subject.id,
                    child: TrText(subject.name),
                  ),
              ],
              onChanged: (value) => setState(() => _subjectId = value ?? ''),
            ),
          ],
          const SizedBox(height: ZakerSpacing.md),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'وقت الامتحان بالدقايق',
              hintText: 'سيبه فاضي لو من غير وقت',
              helperText: 'من ١ لـ ١٨٠ دقيقة، بيتحسب من ساعة الجهاز.',
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _sectionTitle(theme, 'ميعاد الامتحان'),
          Text(
            'المواعيد بتوقيت جهازك. لو سبتها فاضية، الامتحان بيفضل متاح '
            'لحد ما تقفله.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          _MomentField(
            label: 'يفتح',
            value: _opensAt,
            onPick: () => _pickMoment(_opensAt, (value) {
              setState(() => _opensAt = value);
            }),
            onClear: () => setState(() => _opensAt = null),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          _MomentField(
            label: 'يقفل',
            value: _closesAt,
            onPick: () => _pickMoment(_closesAt, (value) {
              setState(() => _closesAt = value);
            }),
            onClear: () => setState(() => _closesAt = null),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _sectionTitle(theme, 'ظهور النتيجة'),
          SegmentedButton<BatchExamResultsMode>(
            segments: const [
              ButtonSegment(
                value: BatchExamResultsMode.immediately,
                label: TrText('فور التسليم'),
              ),
              ButtonSegment(
                value: BatchExamResultsMode.afterClose,
                label: TrText('بعد الإغلاق'),
              ),
            ],
            selected: {_resultsMode},
            onSelectionChanged: (selection) =>
                setState(() => _resultsMode = selection.first),
          ),
          if (_resultsMode == BatchExamResultsMode.afterClose &&
              _closesAt == null)
            Padding(
              padding: const EdgeInsets.only(top: ZakerSpacing.xs),
              child: Text(
                '«بعد الإغلاق» محتاج ميعاد إغلاق.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: ZakerSpacing.md),
          _sectionTitle(theme, 'عدد المحاولات'),
          SegmentedButton<BatchExamAttemptPolicy>(
            segments: const [
              ButtonSegment(
                value: BatchExamAttemptPolicy.single,
                label: TrText('مرة واحدة'),
              ),
              ButtonSegment(
                value: BatchExamAttemptPolicy.limited,
                label: TrText('محدود'),
              ),
              ButtonSegment(
                value: BatchExamAttemptPolicy.unlimited,
                label: TrText('مفتوح'),
              ),
            ],
            selected: {_attemptPolicy},
            onSelectionChanged: (selection) =>
                setState(() => _attemptPolicy = selection.first),
          ),
          if (_attemptPolicy == BatchExamAttemptPolicy.limited) ...[
            const SizedBox(height: ZakerSpacing.sm),
            TextField(
              controller: _maxAttempts,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'أقصى عدد محاولات',
                helperText: 'من ١ لـ ١٠.',
              ),
            ),
          ],
          const SizedBox(height: ZakerSpacing.xl),
          Row(
            children: [
              Expanded(child: _sectionTitle(theme, 'الأسئلة')),
              Text(
                '${arabicDigits(_questions.length)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (pdfs.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed:
                    _generating ? null : () => _generateFromResource(pdfs),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const TrText('توليد أسئلة من ملف PDF'),
              ),
            ),
          for (var index = 0; index < _questions.length; index++)
            _questionCard(theme, index),
          const SizedBox(height: ZakerSpacing.sm),
          OutlinedButton.icon(
            onPressed: _questions.length >= 50
                ? null
                : () => setState(() => _questions.add(_QuestionDraft())),
            icon: const Icon(Icons.add_rounded),
            label: const TrText('ضيف سؤال'),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          if (isEditing && widget.original!.isPublished)
            Text(
              'الامتحان اتنشر. مش هينفع يتعدل من هنا.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _saveAndPublish,
              icon: const Icon(Icons.publish_rounded),
              label: const TrText('حفظ ونشر'),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const TrText('حفظ كمسودة'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
        child: TrText(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _questionCard(ThemeData theme, int index) {
    final question = _questions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TrText(
                    'سؤال ${arabicDigits(index + 1)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'احذف السؤال',
                  onPressed: _questions.length <= 1
                      ? null
                      : () => setState(() {
                            _questions.removeAt(index).dispose();
                          }),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            TextField(
              controller: question.prompt,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'نص السؤال'),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            RadioGroup<int>(
              groupValue: question.correctIndex,
              onChanged: (value) => setState(
                () => question.correctIndex = value ?? 0,
              ),
              child: Column(
                children: [
                  for (var option = 0;
                      option < question.options.length;
                      option++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
                      child: Row(
                        children: [
                          Radio<int>(value: option),
                          Expanded(
                            child: TextField(
                              controller: question.options[option],
                              maxLength: 240,
                              decoration: InputDecoration(
                                labelText: 'اختيار ${arabicDigits(option + 1)}',
                                counterText: '',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'احذف الاختيار',
                            onPressed: question.options.length <= 2
                                ? null
                                : () => setState(() {
                                      question.removeOption(option);
                                      if (question.correctIndex >=
                                          question.options.length) {
                                        question.correctIndex =
                                            question.options.length - 1;
                                      }
                                    }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: question.options.length >= 6
                    ? null
                    : () => setState(question.addOption),
                icon: const Icon(Icons.add_rounded),
                label: const TrText('ضيف اختيار'),
              ),
            ),
            TextField(
              controller: question.explanation,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفسير الإجابة',
                helperText: 'بيظهر بعد التسليم بس.',
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const TrText('مصدر السؤال (اختياري)'),
              childrenPadding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
              children: [
                TextField(
                  controller: question.sourcePage,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'رقم الصفحة'),
                ),
                const SizedBox(height: ZakerSpacing.sm),
                TextField(
                  controller: question.sourceExcerpt,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'اقتباس من الصفحة',
                    helperText: 'بيظهر مع النتيجة.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMoment(
    DateTime? current,
    void Function(DateTime) onPicked,
  ) async {
    final now = ref.read(examClockProvider)();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null || !mounted) return;
    onPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _generateFromResource(List<BatchResource> pdfs) async {
    final resource = await showModalBottomSheet<BatchResource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: TrText('ولّد أسئلة من ملف'),
              subtitle: TrText('الأسئلة بتتولّد من نص الملف على الجهاز.'),
            ),
            for (final pdf in pdfs)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: TrText(pdf.title),
                onTap: () => Navigator.of(sheetContext).pop(pdf),
              ),
          ],
        ),
      ),
    );
    if (resource == null || !mounted) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final questions = await ref.read(
        studyTestProvider(
          (batchId: widget.batchId, resourceId: resource.id),
        ).future,
      );
      if (!mounted) return;
      final drafts = [
        for (final question in questions)
          if (question.choices.length >= 2 && question.choices.length <= 6)
            _QuestionDraft.fromStudyQuestion(question),
      ];
      if (drafts.isEmpty) {
        setState(() => _error = 'مفيش أسئلة واضحة في الملف ده.');
        return;
      }
      setState(() {
        _questions.addAll(drafts.take(50 - _questions.length));
      });
    } on BatchFailure catch (failure) {
      if (mounted) setState(() => _error = batchErrorText(failure));
    } on Object {
      if (mounted) {
        setState(() => _error = 'توليد الأسئلة ما نجحش. جرّب ملف تاني.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _saveDraft() => _save(publish: false);

  Future<void> _saveAndPublish() => _save(publish: true);

  Future<void> _save({required bool publish}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final exam = _buildExam();
      _validateLocally(exam);
      final saved = await ref
          .read(batchExamsControllerProvider)
          .save(widget.batchId, exam);
      if (publish) {
        await ref
            .read(batchExamsControllerProvider)
            .publish(widget.batchId, saved.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: TrText(
              publish ? 'الامتحان اتنشر.' : 'الامتحان اتحفظ كمسودة.',
            ),
          ),
        );
      Navigator.of(context).pop(true);
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = _failureText(failure));
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'الحفظ ما تمّش. جرّب تاني.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BatchExam _buildExam() {
    final minutes = int.tryParse(_minutes.text.trim());
    return BatchExam(
      id: widget.original?.id ?? '',
      batchId: widget.batchId,
      subjectId: _subjectId,
      title: _title.text,
      description: _description.text,
      durationMinutes: minutes ?? 0,
      questions: [
        for (final draft in _questions)
          ExamQuestion(
            id: draft.id,
            prompt: draft.prompt.text,
            answerKind: AnswerKind.multipleChoice,
            options: [for (final option in draft.options) option.text],
            correctIndex: draft.correctIndex,
            explanation: draft.explanation.text,
            source: 'local',
            sourcePage: int.tryParse(draft.sourcePage.text.trim()),
            sourceExcerpt: draft.sourceExcerpt.text,
          ),
      ],
      opensAt: _opensAt,
      closesAt: _closesAt,
      resultsMode: _resultsMode,
      attemptPolicy: _attemptPolicy,
      maxAttempts: _attemptPolicy == BatchExamAttemptPolicy.limited
          ? int.tryParse(_maxAttempts.text.trim()) ?? 0
          : 1,
      sourceResourceId: widget.original?.sourceResourceId ?? '',
      createdBy: widget.original?.createdBy ?? '',
      createdAt: widget.original?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Mirrors the repository checks so the message names the field first.
  void _validateLocally(BatchExam exam) {
    if (exam.title.trim().isEmpty) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'title',
      );
    }
    final minutes = exam.durationMinutes;
    if (_minutes.text.trim().isNotEmpty && (minutes < 1 || minutes > 180)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'durationMinutes',
      );
    }
    if (exam.opensAt != null &&
        exam.closesAt != null &&
        !exam.opensAt!.isBefore(exam.closesAt!)) {
      throw const BatchFailure(
        BatchFailureCode.examWindowInvalid,
        field: 'window',
      );
    }
    if (exam.resultsMode == BatchExamResultsMode.afterClose &&
        exam.closesAt == null) {
      throw const BatchFailure(
        BatchFailureCode.examWindowInvalid,
        field: 'closesAt',
      );
    }
    if (_attemptPolicy == BatchExamAttemptPolicy.limited &&
        (exam.maxAttempts < 1 || exam.maxAttempts > 10)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'maxAttempts',
      );
    }
    if (exam.questions.isEmpty) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'questions',
      );
    }
    for (final question in exam.questions) {
      if (question.prompt.trim().isEmpty) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'prompt',
        );
      }
      final options = [
        for (final option in question.options) option.trim(),
      ];
      if (options.length < 2 ||
          options.length > 6 ||
          options.any((option) => option.isEmpty) ||
          options.map((option) => option.toLowerCase()).toSet().length !=
              options.length) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'options',
        );
      }
      final correct = question.correctIndex;
      if (correct == null || correct < 0 || correct >= options.length) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'correctIndex',
        );
      }
      if (question.explanation.trim().isEmpty) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'explanation',
        );
      }
    }
  }

  String _failureText(BatchFailure failure) {
    if (failure.code == BatchFailureCode.examWindowInvalid) {
      return 'راجع ميعاد الفتح والإغلاق: الفتح لازم قبل الإغلاق، و«بعد '
          'الإغلاق» محتاج ميعاد إغلاق.';
    }
    if (failure.code == BatchFailureCode.conflict) {
      return 'الامتحان اتنشر خلاص، مش هينفع يتعدل.';
    }
    return switch (failure.field) {
      'title' => 'اكتب عنوان الامتحان.',
      'durationMinutes' => 'الوقت لازم يكون من ١ لـ ١٨٠ دقيقة.',
      'maxAttempts' => 'عدد المحاولات لازم يكون من ١ لـ ١٠.',
      'questions' => 'ضيف سؤال واحد على الأقل.',
      'prompt' => 'كل سؤال محتاج نص.',
      'options' => 'كل سؤال محتاج اختيارين على الأقل، من غير تكرار.',
      'correctIndex' => 'اختار الإجابة الصحيحة لكل سؤال.',
      'explanation' => 'اكتب تفسير الإجابة.',
      _ => batchErrorText(failure),
    };
  }
}

class _QuestionDraft {
  _QuestionDraft({
    this.id = '',
    String prompt = '',
    List<String>? options,
    this.correctIndex = 0,
    String explanation = '',
    String sourcePage = '',
    String sourceExcerpt = '',
  })  : prompt = TextEditingController(text: prompt),
        options = [
          for (final option in options ?? const ['', '', '', ''])
            TextEditingController(text: option),
        ],
        explanation = TextEditingController(text: explanation),
        sourcePage = TextEditingController(text: sourcePage),
        sourceExcerpt = TextEditingController(text: sourceExcerpt);

  factory _QuestionDraft.fromQuestion(ExamQuestion question) => _QuestionDraft(
        id: question.id,
        prompt: question.prompt,
        options: [...question.options],
        correctIndex: question.correctIndex ?? 0,
        explanation: question.explanation,
        sourcePage: question.sourcePage?.toString() ?? '',
        sourceExcerpt: question.sourceExcerpt,
      );

  factory _QuestionDraft.fromStudyQuestion(StudyQuestion question) =>
      _QuestionDraft(
        prompt: question.prompt,
        options: [...question.choices],
        correctIndex: question.correctIndex,
        explanation: question.explanation,
        sourcePage: '${question.page}',
        sourceExcerpt: question.evidence,
      );

  final String id;
  final TextEditingController prompt;
  final List<TextEditingController> options;
  final TextEditingController explanation;
  final TextEditingController sourcePage;
  final TextEditingController sourceExcerpt;
  int correctIndex;

  void addOption() => options.add(TextEditingController());

  void removeOption(int index) {
    options.removeAt(index).dispose();
    if (correctIndex > index) correctIndex--;
  }

  void dispose() {
    prompt.dispose();
    for (final option in options) {
      option.dispose();
    }
    explanation.dispose();
    sourcePage.dispose();
    sourceExcerpt.dispose();
  }
}

class _MomentField extends StatelessWidget {
  const _MomentField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: TrText(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: TrText(
            value == null ? 'من غير ميعاد' : formatExamMoment(value!),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: onPick,
          child: TrText(value == null ? 'اختار' : 'غيّر'),
        ),
        if (value != null)
          IconButton(
            tooltip: 'امسح الميعاد',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
      ),
      child: TrText(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
