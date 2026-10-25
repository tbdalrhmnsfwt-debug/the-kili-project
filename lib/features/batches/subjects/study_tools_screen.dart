/// The hub for one PDF's local study tools: extraction, provenance, the three
/// generated artifacts and the honest blocked remote-AI note.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../models/batch_resource.dart';
import '../../../models/study_source.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/study_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../../../widgets/zaker_visuals.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import 'study_widgets.dart';

class StudyToolsScreen extends ConsumerWidget {
  const StudyToolsScreen({
    super.key,
    required this.batchId,
    required this.resourceId,
  });

  final String batchId;
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (batchId: batchId, resourceId: resourceId);
    final state = ref.watch(studyToolsControllerProvider(args));
    final resource = ref.watch(studyResourceProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const TrText('أدوات الدراسة'),
        actions: [
          IconButton(
            tooltip: 'بلّغ عن خطأ',
            onPressed: resource.hasValue
                ? () => _report(context, ref, resource.requireValue)
                : null,
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: resource.when(
        loading: () =>
            const Center(child: LoadingBox(label: 'بنجيب بيانات الملف…')),
        error: (error, _) => _FailureView(
          failure: error is BatchFailure ? error : null,
          onRetry: error is BatchFailure && !_canRetryFailure(error)
              ? null
              : () => ref.invalidate(studyResourceProvider(args)),
        ),
        data: (resource) => _Body(
          args: args,
          state: state,
          resource: resource,
        ),
      ),
    );
  }

  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    BatchResource resource,
  ) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (message == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final uid = ref.read(authUserProvider)?.uid ?? '';
    try {
      await ref.read(studyReportStoreProvider).save(
            uid: uid,
            batchId: batchId,
            resourceId: resource.id,
            message: message,
          );
      messenger.showSnackBar(
        const SnackBar(
          content: TrText(
            'اتحفظ التقرير على الجهاز. إرساله لفريق التطوير محتاج سيرفر.',
          ),
        ),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: TrText('مقدرناش نحفظ التقرير.')),
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.args,
    required this.state,
    required this.resource,
  });

  final StudyResourceArgs args;
  final StudyToolsState state;
  final BatchResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studyToolsControllerProvider(args).notifier);
    final job = state.job;
    if (state.isExtracting && job != null) {
      return _ExtractionView(
        job: job,
        onCancel: controller.cancel,
      );
    }
    if (state.loading && !state.hasDocument) {
      return const Center(child: LoadingBox(label: 'بندوّر على نص محفوظ…'));
    }
    final failure = state.failure;
    if (failure != null && !state.hasDocument) {
      return _FailureView(
        failure: failure,
        onRetry: _canRetryFailure(failure)
            ? () => controller.extract(force: true)
            : null,
      );
    }
    final document = state.document;
    if (document == null) {
      return _IntroView(
        resource: resource,
        onExtract: () => controller.extract(),
      );
    }
    return _DocumentView(
      args: args,
      state: state,
      document: document,
      onExtractAgain: () => controller.extract(force: true),
    );
  }
}

/// Retrying only helps when the cause can change: an encrypted or oversized
/// file stays refused, and no retry may pretend otherwise.
bool _canRetryFailure(BatchFailure failure) => switch (failure.code) {
      BatchFailureCode.encryptedSource ||
      BatchFailureCode.tooManyPages ||
      BatchFailureCode.unsupportedFile ||
      BatchFailureCode.notAuthorized ||
      BatchFailureCode.notFound =>
        false,
      _ => true,
    };

class _IntroView extends StatelessWidget {
  const _IntroView({required this.resource, required this.onExtract});

  final BatchResource resource;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.lg,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        ZakerGlassGlyph(
          icon: Icons.auto_stories_outlined,
          accent: theme.colorScheme.primary,
          size: 56,
          iconSize: 28,
        ),
        const SizedBox(height: ZakerSpacing.md),
        TrText(
          resource.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          'هنقرا نص الـ PDF على جهازك، وبعدين نبني منه أسئلة وبطاقات معلومات '
          'وخريطة. مفيش حاجة بتترفع لأي سيرفر.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: ZakerSpacing.md),
        const _Bullet(
          icon: Icons.memory_rounded,
          text: 'القراءة والتوليد على الجهاز.',
        ),
        const _Bullet(
          icon: Icons.text_snippet_outlined,
          text: 'الصفحات المصوّرة بنحاول نقراها بـ OCR عربي وإنجليزي.',
        ),
        const _Bullet(
          icon: Icons.speed_rounded,
          text: 'حد الملف ٥٠٠ صفحة، والـ OCR لحد ٥٠ صفحة مصوّرة.',
        ),
        const _Bullet(
          icon: Icons.fact_check_outlined,
          text: 'كل سؤال أو معلومة بتيجي مع صفحة الدليل من النص.',
        ),
        const SizedBox(height: ZakerSpacing.lg),
        FilledButton.icon(
          onPressed: onExtract,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const TrText('استخرج النص وابدأ'),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          'الاستخراج ممكن ياخد وقت لو الملف مصوّر. سيب الشاشة مفتوحة.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        const _BlockedAiNote(),
      ],
    );
  }
}

class _ExtractionView extends StatelessWidget {
  const _ExtractionView({required this.job, required this.onCancel});

  final StudyJob job;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = job.total;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.xl,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        Icon(
          Icons.document_scanner_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: ZakerSpacing.md),
        TrText(
          job.message.isEmpty ? 'بنستخرج نص الملف…' : job.message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        LinearProgressIndicator(
          value: total > 0 ? job.progress : null,
          minHeight: 8,
          borderRadius: BorderRadius.circular(ZakerRadius.pill),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        if (total > 0)
          TrText(
            '${arabicDigits(job.done)} من ${arabicDigits(total)} صفحة',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: ZakerSpacing.xl),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const TrText('إلغاء'),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          'الإلغاء بيوقف بعد الصفحة الحالية.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DocumentView extends StatelessWidget {
  const _DocumentView({
    required this.args,
    required this.state,
    required this.document,
    required this.onExtractAgain,
  });

  final StudyResourceArgs args;
  final StudyToolsState state;
  final SourceDocument document;
  final VoidCallback onExtractAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = state.failure;
    final usable = document.hasUsableText;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        _SourceHeader(document: document),
        for (final warning in document.warnings) _WarningCard(text: warning),
        if (failure != null) ...[
          const SizedBox(height: ZakerSpacing.md),
          _InlineError(
            failure: failure,
            onRetry: _canRetryFailure(failure) ? onExtractAgain : null,
          ),
        ],
        const SizedBox(height: ZakerSpacing.lg),
        if (!usable)
          _NoText(document: document, onExtractAgain: onExtractAgain)
        else ...[
          _ToolCard(
            icon: Icons.quiz_outlined,
            title: 'اختبار تفاعلي',
            subtitle: 'أسئلة من النص، وكل إجابة معاها صفحة الدليل. '
                'بتتحفظ محاولتك على الجهاز.',
            onTap: () => context.push(
              ZakerRoutes.batchStudyTest(args.batchId, args.resourceId),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _ToolCard(
            icon: Icons.menu_book_outlined,
            title: 'بنك المعلومات',
            subtitle: 'تعريفات وتواريخ وأرقام وخطوات، مع بحث محلي.',
            onTap: () => context.push(
              ZakerRoutes.batchStudyBank(args.batchId, args.resourceId),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _ToolCard(
            icon: Icons.account_tree_outlined,
            title: 'خريطة ذهنية',
            subtitle: 'العناوين والمفاهيم بترتيبها في الملف، '
                'وبديل نصي للقارئ الصوتي.',
            onTap: () => context.push(
              ZakerRoutes.batchStudyMap(args.batchId, args.resourceId),
            ),
          ),
        ],
        const SizedBox(height: ZakerSpacing.lg),
        const _BlockedAiNote(),
        const SizedBox(height: ZakerSpacing.md),
        TextButton.icon(
          onPressed: onExtractAgain,
          icon: const Icon(Icons.refresh_rounded),
          label: const TrText('اقرا الملف تاني'),
        ),
        TrText(
          'إعادة القراءة بتستبدل النص المحفوظ لو الملف اتغير.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SourceHeader extends StatelessWidget {
  const _SourceHeader({required this.document});

  final SourceDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages =
        document.pageCount > 0 ? document.pageCount : document.pages.length;
    final details = <String>[
      '${arabicDigits(pages)} صفحة',
      if (document.ocrPageCount > 0)
        '${arabicDigits(document.ocrPageCount)} صفحة بـ OCR',
      if (document.fromCache) 'محفوظ من زيارة سابقة',
    ];
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZakerGlassGlyph(
                icon: Icons.picture_as_pdf_outlined,
                accent: theme.colorScheme.primary,
                size: 40,
                iconSize: 20,
                radius: ZakerRadius.sm,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: TrText(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const StudyLocalBadge(compact: true),
              for (final detail in details)
                TrText(
                  detail,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: ZakerSpacing.sm),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.failure, this.onRetry});

  final BatchFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              batchErrorText(failure),
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const TrText('جرّب تاني'),
            ),
        ],
      ),
    );
  }
}

class _NoText extends StatelessWidget {
  const _NoText({required this.document, required this.onExtractAgain});

  final SourceDocument document;
  final VoidCallback onExtractAgain;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.text_snippet_outlined,
      title: 'مفيش نص كفاية في الملف',
      message: document.warnings.isEmpty
          ? 'الصفحات كلها من غير نص مقروء. لو الملف نسخة مصوّرة، '
              'OCR ممكن يقراها — جرّب استخراج تاني.'
          : 'شوف التحذيرات فوق. الصفحات اللي من غير نص مش بنخمّن محتواها.',
      action: FilledButton.icon(
        onPressed: onExtractAgain,
        icon: const Icon(Icons.refresh_rounded),
        label: const TrText('جرّب استخراج تاني'),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: ZakerRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            children: [
              ZakerGlassGlyph(
                icon: icon,
                accent: theme.colorScheme.primary,
                size: 42,
                iconSize: 21,
                radius: ZakerRadius.sm,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZakerSpacing.xs),
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
}

class _BlockedAiNote extends StatelessWidget {
  const _BlockedAiNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'ملخص أو شرح بالذكاء الاصطناعي',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  blockedCapabilityText(BlockedCapability.remoteAi),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                TrText(
                  'البديل المتاح: الاختبار وبنك المعلومات والخريطة، '
                  'وكلهم من نص الملف.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({this.failure, this.onRetry});

  final BatchFailure? failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return EmptyState(
      icon: failure?.code == BatchFailureCode.encryptedSource
          ? Icons.lock_outline_rounded
          : Icons.error_outline_rounded,
      title: failure == null ? 'مقدرناش نفتح الملف' : batchErrorText(failure),
      message: failure == null
          ? 'الملف مش موجود في الدفعة أو مش PDF.'
          : _failureHint(failure),
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('جرّب تاني'),
            ),
    );
  }

  static String _failureHint(BatchFailure failure) => switch (failure.code) {
        BatchFailureCode.encryptedSource =>
          'أدوات الدراسة مش هتشتغل على ملف محمي. لو عندك نسخة من غير حماية '
              'ارفعها في الدفعة.',
        BatchFailureCode.tooManyPages => 'الحد الأقصى ٥٠٠ صفحة للملف الواحد، '
            'عشان القراءة تفضل معقولة على الموبايل.',
        BatchFailureCode.missingFile => 'ارفع الملف تاني في الدفعة وبعدين '
            'جرّب استخراج النص.',
        BatchFailureCode.extractionFailed => 'الملف ممكن يكون تالف أو الصيغة '
            'مش مدعومة. جرّب ملف تاني.',
        BatchFailureCode.cancelled => 'الاستخراج اتوقف قبل ما يخلص.',
        BatchFailureCode.unsupportedFile => 'أدوات الدراسة للـ PDF بس.',
        BatchFailureCode.notFound => 'الملف اتمسح من الدفعة.',
        BatchFailureCode.notAuthorized => 'مش عضو في الدفعة دي.',
        _ => 'جرّب تاني. لو المشكلة فضلت، ابعت تقرير من زر العلم.',
      };
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const TrText('بلّغ عن خطأ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'اكتب إيه اللي غلط في السؤال أو المعلومة. التقرير بيتحفظ على '
              'جهازك بس، ومش بيتبعت لحد تاني.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: _messageController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'وصف المشكلة',
                alignLabelWithHint: true,
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
          child: const TrText('حفظ على الجهاز'),
        ),
      ],
    );
  }
}
