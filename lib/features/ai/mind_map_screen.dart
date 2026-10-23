/// The mind-map builder.
///
/// Shipped strings this screen is built from:
///   * `الخريطة الذهنية`
///   * `اعمل خريطة ذهنية`
///   * `اختار شكل من ١٢: خريطة مفاهيم، جدول مقارنة، مخطط خطوات، عضمة السمكة،
///     وكروت سوشيال وغيرهم.`
///   * `بنرسم الخريطة…` / `بنرسم خريطة أفكارك…`
///   * `تمام! الخريطة اتحفظت في مكتبتك ✅`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/ai.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The mind-map screen.
class MindMapScreen extends ConsumerStatefulWidget {
  const MindMapScreen({super.key, this.sourceText = '', this.title = 'خريطة'});

  /// The text the map is built from.
  final String sourceText;

  /// The title shown at the root of the map.
  final String title;

  @override
  ConsumerState<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends ConsumerState<MindMapScreen> {
  MapStyle _style = MapStyle.conceptMap;
  MindMap? _map;
  bool _working = false;

  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.title == 'خريطة' ? '' : widget.title,
    );
    _textController = TextEditingController(text: widget.sourceText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final typedTitle = _titleController.text.trim();
    final typedText = _textController.text.trim();
    setState(() => _working = true);
    final service = ref.read(aiServiceProvider);
    final map = await service.mindMap(
      title: typedTitle.isEmpty ? widget.title : typedTitle,
      text: typedText.isEmpty ? widget.sourceText : typedText,
      style: _style,
    );
    if (!mounted) return;
    setState(() {
      _map = map;
      _working = false;
    });
  }

  void _save() {
    final map = _map;
    if (map == null) return;
    final outputs = ref.read(aiOutputsProvider);
    ref.read(aiOutputsProvider.notifier).state = [
      AiOutput(
        id: map.id,
        kind: 'mindmap',
        title: map.title,
        createdAt: DateTime.now(),
        preview: '${map.nodeCount} عنصر · ${map.style.label}',
      ),
      ...outputs,
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: TrText('تمام! الخريطة اتحفظت في مكتبتك ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TrText('الخريطة الذهنية'),
        actions: [
          if (_map != null)
            IconButton(
              tooltip: 'احفظ',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _save,
            ),
        ],
      ),
      body: _map == null
          ? _Builder(
              style: _style,
              working: _working,
              titleController: _titleController,
              textController: _textController,
              onStyle: (s) => setState(() => _style = s),
              onBuild: _build,
            )
          : _MapView(map: _map!, onRebuild: () => setState(() => _map = null)),
    );
  }
}

/// The pre-build panel: pick a style, then generate.
class _Builder extends StatelessWidget {
  const _Builder({
    required this.style,
    required this.working,
    required this.titleController,
    required this.textController,
    required this.onStyle,
    required this.onBuild,
  });

  final MapStyle style;
  final bool working;
  final TextEditingController titleController;
  final TextEditingController textController;
  final ValueChanged<MapStyle> onStyle;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        TextField(
          controller: titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'موضوع الخريطة',
            hintText: 'مثال: الخلية ووظائف أعضائها',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        TextField(
          controller: textController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'النص أو ملاحظاتك (اختياري)',
            hintText: 'الصق فقرة من درسك وهنحوّلها لفروع الخريطة.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        TrText(
          'اختار شكل من ${MapStyle.values.length}: '
          '${MapStyle.values.take(4).map((s) => s.label).join('، ')} وغيرهم.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: ZakerSpacing.sm,
            crossAxisSpacing: ZakerSpacing.sm,
            childAspectRatio: 1.4,
          ),
          itemCount: MapStyle.values.length,
          itemBuilder: (context, index) {
            final s = MapStyle.values[index];
            final selected = s == style;
            return InkWell(
              borderRadius: BorderRadius.circular(ZakerRadius.md),
              onTap: () => onStyle(s),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(ZakerSpacing.xs),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : (theme.dividerTheme.color ?? Colors.black12),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: TrText(
                  s.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: ZakerSpacing.xl),
        FilledButton.icon(
          onPressed: working ? null : onBuild,
          icon: working
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.account_tree_rounded),
          label: TrText(working ? 'بنرسم الخريطة…' : 'اعمل خريطة ذهنية'),
        ),
      ],
    );
  }
}

/// The rendered map.
class _MapView extends StatelessWidget {
  const _MapView({required this.map, required this.onRebuild});

  final MindMap map;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: TrText(
                map.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(onPressed: onRebuild, child: const TrText('تغيير')),
          ],
        ),
        const SizedBox(height: ZakerSpacing.sm),
        Wrap(
          spacing: ZakerSpacing.sm,
          runSpacing: ZakerSpacing.sm,
          children: [
            StatChip(
              value: '${map.nodeCount}',
              label: 'عنصر',
              icon: Icons.account_tree_outlined,
            ),
            StatChip(
              value: map.style.label,
              label: 'الشكل',
              icon: Icons.palette_outlined,
              color: ZakerColors.accent,
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.lg),
        _Node(node: map.root, depth: 0),
        if (map.root.children.isEmpty) ...[
          const SizedBox(height: ZakerSpacing.md),
          TrText(
            'الخريطة محتاجة نص أكتر — ارجع واكتب أو الصق فقرة من درسك '
            'عشان نطلع الفروع.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A node and its children, rendered as an indented tree.
class _Node extends StatelessWidget {
  const _Node({required this.node, required this.depth});

  final MapNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = depth == 0;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: depth * ZakerSpacing.lg,
        bottom: ZakerSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZakerSpacing.md,
              vertical: ZakerSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isRoot ? theme.colorScheme.primary : theme.cardTheme.color,
              borderRadius: BorderRadius.circular(ZakerRadius.md),
              border: isRoot
                  ? null
                  : Border.all(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
            ),
            child: TrText(
              node.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isRoot ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (node.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: ZakerSpacing.xs),
              child: TrText(
                node.note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final child in node.children)
            _Node(node: child, depth: depth + 1),
        ],
      ),
    );
  }
}
