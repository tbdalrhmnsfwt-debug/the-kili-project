/// The exams tab: pick an exam mode, start a quiz, or open the question bank.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The exams tab.
class ExamHomeScreen extends ConsumerWidget {
  const ExamHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(examSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText('الاختبارات')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          if (session != null) ...[
            _ActiveSessionCard(session: session),
            const SizedBox(height: ZakerSpacing.lg),
          ],
          const SectionHeader(
            title: 'أنواع الاختبارات',
            icon: Icons.quiz_rounded,
          ),
          _ModeCard(
            title: 'امتحان دراسي',
            subtitle: 'أسئلة من المنهج مع تصحيح فوري',
            icon: Icons.fact_check_rounded,
            onTap: () => _startFromLesson(context, ref),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _ModeCard(
            title: 'بنك أسئلة',
            subtitle: 'اتمرن على أسئلة أي درس',
            icon: Icons.storage_rounded,
            onTap: () => _startFromLesson(context, ref),
          ),
          const SizedBox(height: ZakerSpacing.md),
          _ModeCard(
            title: 'امتحان الشهادة الإعدادية',
            subtitle: 'نموذج امتحان كامل مع التصحيح',
            icon: Icons.workspace_premium_rounded,
            onTap: () => context.push(ZakerRoutes.quiz),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(title: 'تحديات', icon: Icons.bolt_rounded),
          _ModeCard(
            title: 'تحدي جديد',
            subtitle: 'سؤال كل يوم — وكمّل السلسلة',
            icon: Icons.local_fire_department_rounded,
            onTap: () => context.push(ZakerRoutes.quiz),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          Center(
            child: TrText(
              'النتيجة محسوبة أوتوماتيك — مش بتكتبها بإيدك',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startFromLesson(BuildContext context, WidgetRef ref) {
    context.push(ZakerRoutes.quiz);
  }
}

/// Shows the exam currently in progress.
class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.session});

  final ExamSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: ZakerRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: TrText(
                  session.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(value: session.progress),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            '${session.answeredCount} من ${session.total}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A selectable exam mode.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZakerRadius.sm),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
