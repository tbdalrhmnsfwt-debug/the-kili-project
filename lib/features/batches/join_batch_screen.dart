/// The eight-digit code entry and its honest local-only states.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/batches/batch_code_service.dart';
import '../../core/batches/batch_join_service.dart';
import '../../core/theme.dart';
import '../../providers/batch_providers.dart';
import '../../widgets/tr_text.dart';

class JoinBatchScreen extends ConsumerStatefulWidget {
  const JoinBatchScreen({super.key});

  @override
  ConsumerState<JoinBatchScreen> createState() => _JoinBatchScreenState();
}

class _JoinBatchScreenState extends ConsumerState<JoinBatchScreen> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  JoinCodeResolution? _resolution;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const TrText('انضم بكود')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const SizedBox(height: ZakerSpacing.sm),
          Icon(
            Icons.key_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: ZakerSpacing.md),
          TrText(
            'اكتب كود الدفعة',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'الكود ٨ أرقام. المسافات والشرطات مسموحة، والأرقام العربية كمان.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          TrText(
            'كود الدفعة',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9٠-٩۰-۹\s\-]'),
                ),
                const _JoinCodeFormatter(),
              ],
              decoration: const InputDecoration(
                hintText: '1234 5678',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _resolve(),
              onChanged: (_) {
                if (_resolution != null) setState(() => _resolution = null);
              },
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _resolve,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: const TrText('تحقق من الكود'),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          if (_resolution != null) _ResultCard(resolution: _resolution!),
          const SizedBox(height: ZakerSpacing.lg),
          _JoinNote(
            text: 'الكود ده دعوة مش تسجيل دخول. النسخة المحلية بتدوّر على '
                'الدفعات اللي على الجهاز ده بس؛ مفيش بحث على السيرفر.',
          ),
        ],
      ),
    );
  }

  Future<void> _resolve() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _resolution = null;
    });
    try {
      final resolve = ref.read(batchJoinResolverProvider);
      final result = await resolve(_code.text);
      if (!mounted) return;
      setState(() => _resolution = result);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _resolution = const JoinCodeResolution(
          JoinCodeState.storageError,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Keeps at most eight digits and shows them as `1234 5678`.
class _JoinCodeFormatter extends TextInputFormatter {
  const _JoinCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = BatchCodeService.digitsOnly(newValue.text);
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final grouped = limited.length > 4
        ? '${limited.substring(0, 4)} ${limited.substring(4)}'
        : limited;
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.resolution});

  final JoinCodeResolution resolution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = _presentation(resolution);
    final color = presentation.isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(presentation.icon, color: color, size: 26),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: TrText(
                  presentation.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            presentation.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (presentation.showPreview) ...[
            const Divider(height: ZakerSpacing.xl),
            _PreviewRow(
              label: 'الدفعة',
              value: resolution.batch?.name ?? 'غير معروف',
            ),
            const SizedBox(height: ZakerSpacing.xs),
            _PreviewRow(
              label: 'صاحب الدفعة',
              value: resolution.ownerName.isEmpty
                  ? 'غير معروف'
                  : resolution.ownerName,
            ),
            const SizedBox(height: ZakerSpacing.xs),
            _PreviewRow(
              label: 'المواد',
              value: resolution.subjectCount == 0
                  ? 'من غير مواد'
                  : '${resolution.subjectCount} مواد',
            ),
            if (resolution.isSuccess) ...[
              const SizedBox(height: ZakerSpacing.md),
              Chip(
                avatar: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                label: const TrText('أنت عضو بالفعل'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static _ResultPresentation _presentation(JoinCodeResolution resolution) {
    return switch (resolution.state) {
      JoinCodeState.invalidFormat => const _ResultPresentation(
          icon: Icons.pin_outlined,
          title: 'الكود مش مكتمل',
          body: 'اكتب ٨ أرقام. المسافات والشرطات والأرقام العربية مسموحة.',
        ),
      JoinCodeState.cooldown => _ResultPresentation(
          icon: Icons.timer_outlined,
          title: 'استنى شوية',
          body: 'محاولات كتير على الجهاز ده. جرّب تاني بعد '
              '${_remainingText(resolution.remaining)}.',
          isError: true,
        ),
      JoinCodeState.notFound => const _ResultPresentation(
          icon: Icons.cloud_off_rounded,
          title: 'مفيش دفعة بالكود ده',
          body: 'الكود مش بيخص دفعة على الجهاز ده. البحث عن دفعة حد تاني '
              'أو على جهاز تاني محتاج سيرفر، ومش متاح في النسخة المحلية.',
          isError: true,
        ),
      JoinCodeState.revoked => const _ResultPresentation(
          icon: Icons.key_off_rounded,
          title: 'الكود اتلغى',
          body: 'صاحب الدفعة لغى الكود ده أو غيّره. اطلب كود جديد.',
          isError: true,
        ),
      JoinCodeState.alreadyMember => const _ResultPresentation(
          icon: Icons.verified_rounded,
          title: 'أنت عضو بالفعل',
          body: 'الدفعة دي على حسابك على الجهاز ده، فمفيش عضوية جديدة '
              'اتعملت ومفيش حاجة اتحركت.',
          showPreview: true,
        ),
      JoinCodeState.pendingUnsupported => const _ResultPresentation(
          icon: Icons.hourglass_empty_rounded,
          title: 'الانضمام مش متاح محليًا',
          body: 'الموافقة على طلب انضمام أو الانضمام لدفعة حد تاني محتاجة '
              'سيرفر. مفيش عضوية اتعملت.',
          showPreview: true,
          isError: true,
        ),
      JoinCodeState.storageError => const _ResultPresentation(
          icon: Icons.folder_off_outlined,
          title: 'مش قادرين نقرا الدفعات',
          body: 'حصل خطأ في التخزين المحلي. جرّب تاني.',
          isError: true,
        ),
    };
  }

  static String _remainingText(Duration duration) {
    if (duration.inSeconds >= 60) {
      final minutes = (duration.inSeconds / 60).ceil();
      return '$minutes دقيقة';
    }
    final seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
    return '$seconds ثانية';
  }
}

class _ResultPresentation {
  const _ResultPresentation({
    required this.icon,
    required this.title,
    required this.body,
    this.isError = false,
    this.showPreview = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isError;
  final bool showPreview;
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: TrText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: ZakerSpacing.sm),
        Expanded(
          child: TrText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _JoinNote extends StatelessWidget {
  const _JoinNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
    );
  }
}
