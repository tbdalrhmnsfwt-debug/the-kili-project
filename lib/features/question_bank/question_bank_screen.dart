/// The question bank: real practice sets built from the bundled library.
///
/// Shipped strings this screen is built from:
///   * `بنك الأسئلة`
///   * `بنك الأسئلة اللي في مكتبتك`
///   * `اختر مصدرك، وهنطلعلك بنك أسئلة بكل الأنواع تحله وتراجع بيه.`
///   * `مكتبتك لسه فاضية`
///
/// Banks are generated on-device from the readable textbooks when the screen
/// opens, so the list and the games are never empty on a fresh install.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/question_bank_builder.dart';
import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The banks the user has saved.
class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  bool _seeding = false;
  String? _subject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  /// Builds banks from the library when none exist yet.
  Future<void> _seed({bool force = false}) async {
    if (_seeding) return;
    if (!force && ref.read(questionBanksProvider).isNotEmpty) return;

    setState(() => _seeding = true);
    try {
      final service = ref.read(assetServiceProvider);
      final grades = await ref.read(gradesProvider.future);
      final banks = await buildQuestionBanks(
        service: service,
        grades: grades,
      );
      if (!mounted) return;
      ref.read(questionBanksProvider.notifier).state = banks;
    } catch (_) {
      // The empty state offers a retry, so a failure needs no extra dialog.
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _start(QuestionBank bank) {
    ref.read(examSessionProvider.notifier).state = ExamSession(
      id: 'exam-${bank.id}-${DateTime.now().millisecondsSinceEpoch}',
      title: bank.title,
      questions: bank.questions,
      bookId: bank.bookId,
      subject: bank.subject,
      startedAt: DateTime.now(),
    );
    ref.read(activeChallengeProvider.notifier).state = null;
    ref.read(quizTimeLimitProvider.notifier).state = null;
    context.push(ZakerRoutes.quiz);
  }

  void _delete(QuestionBank bank) {
    final banks = ref.read(questionBanksProvider);
    ref.read(questionBanksProvider.notifier).state = banks
        .where((b) => b.id != bank.id)
        .toList(growable: false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: TrText('اتحذف البنك.')));
  }

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(questionBanksProvider);
    final subjects = <String>{
      for (final bank in banks)
        if (bank.subject != null && bank.subject!.isNotEmpty) bank.subject!,
    }.toList()..sort();
    final visible = _subject == null
        ? banks
        : banks.where((b) => b.subject == _subject).toList(growable: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const TrText(ZakerStrings.s_9cfe0), // بنك الأسئلة
        actions: [
          IconButton(
            tooltip: 'حدّث البنوك من مكتبتك',
            onPressed: _seeding ? null : () => _seed(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const _BankHeader(),
          const SizedBox(height: ZakerSpacing.md),
          const SectionHeader(
            title: ZakerStrings.s_d6b7e, // بنك الأسئلة اللي في مكتبتك
            icon: Icons.folder_rounded,
          ),
          if (_seeding) ...[
            const LinearProgressIndicator(minHeight: 4),
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              'بنجهز أسئلة من كتبك… أول مرة ممكن تاخد لحظة.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.md),
          ],
          if (banks.isEmpty && !_seeding)
            Column(
              children: [
                const EmptyState(
                  icon: Icons.inbox_rounded,
                  title: ZakerStrings.s_15130, // مكتبتك لسه فاضية
                  message:
                      'مفيش بنوك أسئلة متاحة دلوقتي. جرّب تجهيزها من كتبك تاني.',
                ),
                const SizedBox(height: ZakerSpacing.sm),
                FilledButton.icon(
                  onPressed: () => _seed(force: true),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const TrText('جهّز البنوك'),
                ),
              ],
            )
          else if (banks.isNotEmpty) ...[
            if (subjects.length > 1) ...[
              Wrap(
                spacing: ZakerSpacing.sm,
                runSpacing: ZakerSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const TrText('الكل'),
                    selected: _subject == null,
                    onSelected: (_) => setState(() => _subject = null),
                  ),
                  for (final subject in subjects)
                    ChoiceChip(
                      label: TrText(subject),
                      selected: _subject == subject,
                      onSelected: (_) => setState(() => _subject = subject),
                    ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.md),
            ],
            if (visible.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'مفيش بنوك للمادة دي',
              )
            else
              for (final bank in visible) ...[
                _BankTile(
                  bank: bank,
                  onStart: () => _start(bank),
                  onDelete: () => _delete(bank),
                ),
                const SizedBox(height: ZakerSpacing.sm),
              ],
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              'الأسئلة اتولدت من كتبك على الجهاز — كل بنك بيبدأ مراجعة كاملة.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The gradient introduction at the top of the screen.
class _BankHeader extends StatelessWidget {
  const _BankHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [theme.colorScheme.primary, ZakerColors.primaryDark],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ZakerRadius.md),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: ZakerSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'من كتبك… ليك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                TrText(
                  ZakerStrings.s_b96f7, // اختر مصدرك، وهنطلعلك بنك أسئلة…
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One saved bank.
class _BankTile extends StatelessWidget {
  const _BankTile({
    required this.bank,
    required this.onStart,
    required this.onDelete,
  });

  final QuestionBank bank;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStart,
        borderRadius: ZakerRadius.card,
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
                padding: const EdgeInsets.all(ZakerSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZakerRadius.sm),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      bank.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      '${bank.length} سؤال'
                      '${bank.subject == null ? '' : ' · ${bank.subject}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ابدأ المراجعة',
                onPressed: onStart,
                icon: Icon(
                  Icons.play_circle_fill_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: TrText('حذف البنك')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
