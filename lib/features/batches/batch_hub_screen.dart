/// The batch hub: header, chat preview and the four local sections.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/batches/batch_code_service.dart';
import '../../core/batches/batch_failure.dart';
import '../../core/batches/batch_store.dart';
import '../../core/batches/hub_summary.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/batch_chat.dart';
import '../../models/batch_resource.dart';
import '../../providers/app_providers.dart';
import '../../providers/batch_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/zaker_visuals.dart';
import 'batch_error_text.dart';
import 'widgets/batch_labels.dart';
import 'widgets/hub_section_card.dart';

class BatchHubScreen extends ConsumerWidget {
  const BatchHubScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const TrText('الدفعة'),
        actions: [
          IconButton(
            tooltip: 'عن الدفعة دي',
            onPressed: () => _showHelp(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: LoadingBox(label: 'بنفتح الدفعة…')),
        error: (error, _) => _HubError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
        data: (snapshot) => _HubBody(
          batchId: batchId,
          snapshot: snapshot,
          uid: uid,
        ),
      ),
    );
  }

  Future<void> _showHelp(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            0,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'الدفعة دي على الجهاز ده',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              const _HelpLine(
                icon: Icons.key_rounded,
                text: 'الكود بيلاقي الدفعة على الجهاز نفسه. هو دعوة مش تسجيل '
                    'دخول، ومش بيشتغل على جهاز تاني.',
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const _HelpLine(
                icon: Icons.phonelink_lock_rounded,
                text: 'الملفات والملاحظات محفوظة في مساحة خاصة بحسابك على '
                    'الجهاز ده. مفيش رفع لمخزن سحابي.',
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const _HelpLine(
                icon: Icons.groups_2_outlined,
                text: 'مفيش أعضاء تانيين ولا مزامنة لحد ما يبقى فيه سيرفر. '
                    'إدارة الأعضاء والإشعارات الجماعية محتاجة سيرفر.',
              ),
              const SizedBox(height: ZakerSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const TrText('تمام'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({
    required this.batchId,
    required this.snapshot,
    required this.uid,
  });

  final String batchId;
  final BatchSnapshot snapshot;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(batchHubDataProvider(batchId));
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        _HubHeader(snapshot: snapshot, uid: uid),
        const SizedBox(height: ZakerSpacing.md),
        _ChatPreviewCard(batchId: batchId),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(title: 'أقسام الدفعة'),
        _HubSections(
          batchId: batchId,
          snapshot: snapshot,
          uid: uid,
          hub: hub,
        ),
        const SizedBox(height: ZakerSpacing.lg),
      ],
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.snapshot, required this.uid});

  final BatchSnapshot snapshot;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = snapshot.batch;
    final isOwner = batch.ownerUid == uid;
    final memberCount = snapshot.members.length;
    final membersLabel = memberCount == 1
        ? 'عضو واحد على الجهاز'
        : '${arabicDigits(memberCount)} أعضاء على الجهاز';
    final code = batch.codeState;

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZakerGlassGlyph(
                icon: Icons.groups_2_rounded,
                accent: theme.colorScheme.primary,
                size: 46,
                iconSize: 24,
                radius: ZakerRadius.sm,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      batch.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: ZakerSpacing.xs,
                      runSpacing: ZakerSpacing.xs,
                      children: [
                        _Pill(
                          icon: isOwner
                              ? Icons.workspace_premium_outlined
                              : Icons.person_outline_rounded,
                          label: isOwner ? 'صاحب الدفعة' : 'عضو',
                        ),
                        _Pill(
                          icon: Icons.phone_android_rounded,
                          label: membersLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isOwner) ...[
            const SizedBox(height: ZakerSpacing.md),
            if (code.isActive)
              _CodeRow(code: BatchCodeService.format(code.code))
            else
              const _InfoLine(
                icon: Icons.key_off_rounded,
                text: 'كود الدعوة متوقف.',
              ),
          ],
          const SizedBox(height: ZakerSpacing.sm),
          const _InfoLine(
            icon: Icons.phonelink_lock_rounded,
            text: 'الدفعة وملفاتها على الجهاز ده بس.',
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(ZakerRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          await Clipboard.setData(
              ClipboardData(text: code.replaceAll(' ', '')));
          messenger.showSnackBar(
            const SnackBar(content: TrText('الكود اتنسخ.')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.md,
            vertical: ZakerSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.key_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'كود الدعوة',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      code,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatPreviewCard extends ConsumerWidget {
  const _ChatPreviewCard({required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(batchHubDataProvider(batchId));
    return hub.when(
      loading: () => const _ChatCard(
        subtitle: 'بنقرا المحادثة…',
        loading: true,
      ),
      error: (_, __) => const _ChatCard(
        subtitle: 'مقدرناش نقرا المحادثة.',
        unavailable: true,
      ),
      data: (data) {
        if (!data.chatAvailable) {
          return const _ChatCard(
            subtitle: 'مقدرناش نقرا المحادثة.',
            unavailable: true,
          );
        }
        final message = data.lastMessage;
        return _ChatCard(
          subtitle: message == null ? 'لسه مفيش رسائل' : _preview(message),
        );
      },
    );
  }

  static String _preview(ChatMessage message) {
    if (message.deletedAt != null) return 'رسالة اتمسحت';
    final body =
        message.kind == ChatMessageKind.voice ? 'رسالة صوتية' : message.text;
    if (body.isEmpty) return 'رسالة';
    return '${message.authorName}: $body';
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.subtitle,
    this.unavailable = false,
    this.loading = false,
  });

  final String subtitle;
  final bool unavailable;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        unavailable ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: unavailable
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
            ),
            child: Icon(Icons.forum_outlined, size: 21, color: accent),
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: TrText(
                        'المحادثة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TrText(
                      'محادثة على الجهاز',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ZakerSkeleton(height: 12),
                  )
                else
                  TrText(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: unavailable
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
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

class _HubSections extends ConsumerWidget {
  const _HubSections({
    required this.batchId,
    required this.snapshot,
    required this.uid,
    required this.hub,
  });

  final String batchId;
  final BatchSnapshot snapshot;
  final String uid;
  final AsyncValue<BatchHubData> hub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = snapshot.batch.subjects.length;
    BatchResource? latestResource;
    for (final resource in snapshot.resources) {
      if (latestResource == null ||
          resource.createdAt.isAfter(latestResource.createdAt)) {
        latestResource = resource;
      }
    }
    final data = hub.valueOrNull;

    return Column(
      children: [
        HubSectionCard(
          icon: Icons.menu_book_rounded,
          title: 'المواد',
          subtitle: latestResource == null
              ? 'مفيش ملفات لسه.'
              : 'أحدث ملف: ${latestResource.title}',
          countLabel: '${arabicDigits(subjects)} مادة · '
              '${arabicDigits(snapshot.resources.length)} ملف',
          onTap: () => context.push(ZakerRoutes.batchSubjects(batchId)),
        ),
        const SizedBox(height: ZakerSpacing.md),
        if (data != null) ...[
          _scheduleCard(context, data),
          const SizedBox(height: ZakerSpacing.md),
          _updatesCard(context, data),
          const SizedBox(height: ZakerSpacing.md),
          _examsCard(context, data),
        ] else if (hub.hasError) ...[
          HubSectionCard(
            icon: Icons.sync_problem_rounded,
            title: 'المواعيد والمستجدات والامتحانات',
            subtitle: 'مقدرناش نقرا الأقسام دي. المواد لسه متاحة.',
            countLabel: '',
            unavailable: true,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TextButton.icon(
            onPressed: () => ref.invalidate(batchHubDataProvider(batchId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const TrText('جرّب تاني'),
          ),
        ] else ...[
          const _SectionSkeleton(),
          const SizedBox(height: ZakerSpacing.md),
          const _SectionSkeleton(),
          const SizedBox(height: ZakerSpacing.md),
          const _SectionSkeleton(),
        ],
      ],
    );
  }

  Widget _scheduleCard(BuildContext context, BatchHubData data) {
    if (!data.schedulesAvailable) {
      return const HubSectionCard(
        icon: Icons.calendar_month_outlined,
        title: 'المواعيد',
        subtitle: 'مقدرناش نقرا ملف المواعيد.',
        countLabel: '',
        unavailable: true,
      );
    }
    final published = data.scheduleEntryCount;
    final drafts = data.schedules.length;
    return HubSectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'المواعيد',
      subtitle: published > 0
          ? 'مواعيد الجدول محفوظة على الجهاز.'
          : drafts > 0
              ? 'فيه جدول لسه مسودة ومااتنشرش.'
              : 'مفيش مواعيد لسه.',
      countLabel:
          published > 0 ? '${arabicDigits(published)} حصة' : 'مفيش حصص منشورة',
    );
  }

  Widget _updatesCard(BuildContext context, BatchHubData data) {
    if (!data.updatesAvailable) {
      return const HubSectionCard(
        icon: Icons.campaign_outlined,
        title: 'المستجدات',
        subtitle: 'مقدرناش نقرا ملف المستجدات.',
        countLabel: '',
        unavailable: true,
      );
    }
    final latest = data.latestUpdate;
    final unread = data.unreadUpdates(uid);
    return HubSectionCard(
      icon: Icons.campaign_outlined,
      title: 'المستجدات',
      subtitle: latest == null ? 'مفيش مستجدات لسه.' : latest.title,
      countLabel: data.updates.isEmpty
          ? 'مفيش مستجدات'
          : '${arabicDigits(data.updates.length)} مستجد',
      badge: unread,
    );
  }

  Widget _examsCard(BuildContext context, BatchHubData data) {
    if (!data.examsAvailable) {
      return const HubSectionCard(
        icon: Icons.quiz_outlined,
        title: 'امتحانات',
        subtitle: 'مقدرناش نقرا ملف الامتحانات.',
        countLabel: '',
        unavailable: true,
      );
    }
    final latest = data.latestExam;
    return HubSectionCard(
      icon: Icons.quiz_outlined,
      title: 'امتحانات',
      subtitle: latest == null
          ? 'مفيش امتحانات لسه.'
          : '${latest.title}${latest.isPublished ? '' : ' · مسودة'}',
      countLabel: data.exams.isEmpty
          ? 'مفيش امتحانات'
          : '${arabicDigits(data.exams.length)} امتحان',
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZakerSkeleton(height: 14, width: 120),
          SizedBox(height: ZakerSpacing.sm),
          ZakerSkeleton(height: 11),
          SizedBox(height: 6),
          ZakerSkeleton(height: 11, width: 160),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          TrText(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: TrText(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: ZakerSpacing.sm),
        Expanded(
          child: TrText(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _HubError extends StatelessWidget {
  const _HubError({this.failure, required this.onRetry});

  final BatchFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              failure == null
                  ? 'مش قادرين نفتح الدفعة.'
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
