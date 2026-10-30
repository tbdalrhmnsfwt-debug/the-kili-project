/// The local mind map of one PDF: a pan-and-zoom tree, plus a plain-text
/// outline that screen readers and small screens can follow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/study_source.dart';
import '../../../providers/study_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import 'study_widgets.dart';

class BatchMindMapScreen extends ConsumerStatefulWidget {
  const BatchMindMapScreen({
    super.key,
    required this.batchId,
    required this.resourceId,
  });

  final String batchId;
  final String resourceId;

  @override
  ConsumerState<BatchMindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<BatchMindMapScreen> {
  bool _asList = false;

  @override
  Widget build(BuildContext context) {
    final args = (batchId: widget.batchId, resourceId: widget.resourceId);
    final document = ref.watch(studyDocumentProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const TrText('خريطة ذهنية'),
        actions: [
          IconButton(
            tooltip: _asList ? 'عرض كخريطة' : 'عرض كقائمة',
            onPressed: document.valueOrNull == null
                ? null
                : () => setState(() => _asList = !_asList),
            icon: Icon(
              _asList ? Icons.account_tree_outlined : Icons.view_list_rounded,
            ),
          ),
        ],
      ),
      body: document.when(
        loading: () =>
            const Center(child: LoadingBox(label: 'بنقرا النص المحفوظ…')),
        error: (error, _) => _MapError(
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'مقدرناش نقرا النص المحفوظ.',
          onRetry: () {
            ref.invalidate(studyDocumentProvider(args));
            ref.invalidate(studyMindMapProvider(args));
          },
        ),
        data: (document) {
          if (document == null) return const StudyMissingSource();
          if (!document.hasUsableText) {
            return EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'مفيش نص كفاية لبناء خريطة',
              message: 'الخريطة بتتبني من العناوين والمفاهيم اللي في النص. '
                  'ارجع لصفحة أدوات الدراسة وجرّب استخراج تاني.',
              action: FilledButton.icon(
                onPressed: () {
                  if (context.canPop()) context.pop();
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const TrText('رجوع'),
              ),
            );
          }
          final map = ref.watch(studyMindMapProvider(args));
          return map.when(
            loading: () =>
                const Center(child: LoadingBox(label: 'بنرسم الخريطة…')),
            error: (error, _) => _MapError(
              message: error is BatchFailure
                  ? batchErrorText(error)
                  : 'مقدرناش نبني الخريطة.',
              onRetry: () => ref.invalidate(studyMindMapProvider(args)),
            ),
            data: (map) {
              if (map == null) return const StudyMissingSource();
              return _asList ? _OutlineView(map: map) : _MapView(map: map);
            },
          );
        },
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.map});

  final StudyMindMap map;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            ZakerSpacing.md,
            ZakerSpacing.lg,
            ZakerSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: StudyLocalBadge(compact: true),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    TrText(
                      'اسحب وزوّم',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (map.root.note.isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.xs),
                TrText(
                  map.root.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.5,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(240),
            child: Padding(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              child: _MapBranch(node: map.root, depth: 0),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapBranch extends StatelessWidget {
  const _MapBranch({required this.node, required this.depth});

  final StudyMapNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = node.children;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapNodeCard(node: node, root: depth == 0),
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 18, top: 6),
            child: Container(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: theme.dividerTheme.color ?? Colors.black12,
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _MapBranch(node: child, depth: depth + 1),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MapNodeCard extends StatelessWidget {
  const _MapNodeCard({required this.node, required this.root});

  final StudyMapNode node;
  final bool root;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: root
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        border: Border.all(
          color: root
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TrText(
                  node.label,
                  style: (root
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                    fontWeight: root ? FontWeight.w800 : FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
              if (node.page != null) ...[
                const SizedBox(width: 6),
                StudyPageChip(page: node.page!),
              ],
            ],
          ),
          if (node.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            TrText(
              node.note,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutlineView extends StatelessWidget {
  const _OutlineView({required this.map});

  final StudyMindMap map;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = map.outline;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            ZakerSpacing.md,
            ZakerSpacing.lg,
            ZakerSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: StudyLocalBadge(compact: true),
              ),
              const SizedBox(height: 2),
              TrText(
                'نسخة نصية بنفس ترتيب الخريطة.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.sm,
              ZakerSpacing.lg,
              ZakerSpacing.xxl,
            ),
            itemCount: lines.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TrText(
                lines[index],
                style: index == 0
                    ? theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'مقدرناش نبني الخريطة',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const TrText('جرّب تاني'),
      ),
    );
  }
}
