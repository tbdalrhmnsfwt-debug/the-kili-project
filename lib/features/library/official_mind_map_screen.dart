/// An interactive mind map built from one extracted official lesson.
///
/// The map is pannable and zoomable, its branches expand and collapse, and the
/// outline view is always available as a structured fallback. Every node's
/// note carries the page it came from.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/grounded_study.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/ai.dart';
import '../../models/official_book.dart';
import '../../providers/app_providers.dart';
import '../../providers/official_library_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

enum _MindView { map, outline }

/// Interactive map of a lesson's concepts.
class OfficialMindMapScreen extends ConsumerStatefulWidget {
  const OfficialMindMapScreen({
    super.key,
    required this.bookId,
    required this.sectionId,
  });

  final String bookId;
  final String sectionId;

  @override
  ConsumerState<OfficialMindMapScreen> createState() =>
      _OfficialMindMapScreenState();
}

class _OfficialMindMapScreenState extends ConsumerState<OfficialMindMapScreen> {
  _MindView _view = _MindView.map;
  final _controller = TransformationController();
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(officialBooksProvider).valueOrNull;
    final extractedAsync = ref.watch(officialExtractedProvider(widget.bookId));
    final book = _findBook(catalog);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const TrText('الخريطة الذهنية')),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'الكتاب مش موجود',
          message: 'ارجع للمكتبة الرسمية وافتح الكتاب تاني.',
        ),
      );
    }
    return extractedAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const TrText('الخريطة الذهنية')),
        body: const LoadingBox(label: 'بنرسم الخريطة…'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const TrText('الخريطة الذهنية')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مقدرناش نفتح الدرس',
          message: '$error',
        ),
      ),
      data: (extracted) {
        final section = extracted?.sectionById(widget.sectionId);
        if (extracted == null || section == null) {
          return Scaffold(
            appBar: AppBar(title: const TrText('الخريطة الذهنية')),
            body: const EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'مفيش خريطة',
              message: 'الدرس مش متاح في النسخة المستخرجة.',
            ),
          );
        }
        final passage = OfficialPassage(
          book: book,
          section: section,
          extraction: extracted,
        );
        final map = GroundedStudyService().mindMap(passage);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TrText(
                  'الخريطة الذهنية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                TrText(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'افتح الدرس',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () => context.push(
                  ZakerRoutes.officialSectionPath(book.id, section.id),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                ),
                child: SegmentedButton<_MindView>(
                  segments: const [
                    ButtonSegment(
                      value: _MindView.map,
                      label: Text('خريطة'),
                      icon: Icon(Icons.account_tree_outlined, size: 17),
                    ),
                    ButtonSegment(
                      value: _MindView.outline,
                      label: Text('مخطط'),
                      icon: Icon(Icons.view_list_outlined, size: 17),
                    ),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
                ),
              ),
              if (!passage.isCurrentEdition)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZakerSpacing.lg,
                  ),
                  child: TrText(
                    'الخريطة دي من طبعة قديمة من الكتاب. أعد الاستخراج بعد '
                    'التحديث.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ZakerColors.danger,
                    ),
                  ),
                ),
              Expanded(
                child: _view == _MindView.map
                    ? _MapCanvas(
                        map: map,
                        controller: _controller,
                        fitted: _fitted,
                        onFitRequested: (viewport, canvas) {
                          if (_fitted) return;
                          _fitted = true;
                          _fit(viewport, canvas);
                        },
                        onReset: () {
                          _fitted = false;
                          setState(() {});
                        },
                      )
                    : _OutlineView(map: map),
              ),
              Padding(
                padding: const EdgeInsets.all(ZakerSpacing.sm),
                child: TrText(
                  'المصدر: «${book.titleAr}» · ${passage.citationLabel} · '
                  '${map.nodeCount} عقدة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _fit(Size viewport, Size canvas) {
    if (viewport.width <= 0 || viewport.height <= 0) return;
    final scale = math.min(1.0, viewport.width / canvas.width) * 0.94;
    final dx = (viewport.width - canvas.width * scale) / 2;
    final dy = (viewport.height - canvas.height * scale) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  OfficialBook? _findBook(OfficialBookCatalog? catalog) {
    if (catalog == null) return null;
    for (final book in catalog.books) {
      if (book.id == widget.bookId) return book;
    }
    return null;
  }
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.map,
    required this.controller,
    required this.fitted,
    required this.onFitRequested,
    required this.onReset,
  });

  final MindMap map;
  final TransformationController controller;
  final bool fitted;
  final void Function(Size viewport, Size canvas) onFitRequested;
  final VoidCallback onReset;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final layout = _layout(
      widget.map.root,
      _collapsed,
      nodeHeight: _MapLayout.baseNodeHeight * textScale,
    );
    final canvas = Size(
      1420,
      math.max(640, layout.totalHeight + 120),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!widget.fitted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onFitRequested(viewport, canvas);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: widget.controller,
                constrained: false,
                minScale: 0.25,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(240),
                child: SizedBox(
                  width: canvas.width,
                  height: canvas.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ConnectorPainter(
                            layout: layout,
                            canvasHeight: canvas.height,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      for (final placed in layout.nodes)
                        Positioned(
                          left: placed.left,
                          top: placed.top,
                          width: _MapLayout.nodeWidth,
                          child: _MapNodeCard(
                            placed: placed,
                            collapsed: _collapsed.contains(placed.node.id),
                            onTap: () {
                              if (placed.node.children.isEmpty) {
                                _showNote(context, placed.node);
                              } else {
                                setState(() {
                                  if (!_collapsed.remove(placed.node.id)) {
                                    _collapsed.add(placed.node.id);
                                  }
                                });
                              }
                            },
                            onNote: placed.node.note.isEmpty
                                ? null
                                : () => _showNote(context, placed.node),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'تصغير كل الفروع',
                      icon: const Icon(Icons.unfold_less_rounded, size: 19),
                      onPressed: () => setState(() {
                        _collapsed
                          ..clear()
                          ..addAll(_branchIds(widget.map.root));
                      }),
                    ),
                    IconButton(
                      tooltip: 'فتح كل الفروع',
                      icon: const Icon(Icons.unfold_more_rounded, size: 19),
                      onPressed: () => setState(_collapsed.clear),
                    ),
                    IconButton(
                      tooltip: 'إعادة ضبط العرض',
                      icon: const Icon(Icons.center_focus_strong_rounded, size: 19),
                      onPressed: widget.onReset,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNote(BuildContext context, MapNode node) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: TrText(node.label),
        content: SingleChildScrollView(
          child: TrText(
            node.note.isEmpty ? 'العقدة دي مفيهاش ملاحظة إضافية.' : node.note,
            style: const TextStyle(height: 1.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('قفل'),
          ),
        ],
      ),
    );
  }

  Set<String> _branchIds(MapNode node) {
    final ids = <String>{};
    for (final child in node.children) {
      if (child.children.isNotEmpty) {
        ids.add(child.id);
        ids.addAll(_branchIds(child));
      }
    }
    return ids;
  }
}

class _MapNodeCard extends StatelessWidget {
  const _MapNodeCard({
    required this.placed,
    required this.collapsed,
    required this.onTap,
    required this.onNote,
  });

  final _PlacedNode placed;
  final bool collapsed;
  final VoidCallback onTap;
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depth = placed.depth;
    final baseAccent = switch (depth) {
      0 => theme.colorScheme.primary,
      1 => ZakerColors.primaryLight,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final accent = readableTextColor(baseAccent, theme.colorScheme.surface);
    final page = _pageFromNote(placed.node.note);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(ZakerRadius.md),
            border: Border.all(
              color: accent.withValues(alpha: depth == 0 ? 0.65 : 0.35),
              width: depth == 0 ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TrText(
                      placed.node.label,
                      maxLines: depth == 0 ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: (depth == 0
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.bodySmall)
                          ?.copyWith(
                            fontWeight: depth == 0
                                ? FontWeight.w900
                                : FontWeight.w700,
                            height: 1.35,
                            color: depth == 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                    ),
                  ),
                  if (placed.node.children.isNotEmpty)
                    Icon(
                      collapsed
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                      size: 15,
                      color: accent,
                    ),
                ],
              ),
              if (!collapsed && placed.node.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                TrText(
                  placed.node.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
              if (placed.node.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: TrText(
                    '${placed.node.children.length} فرع',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: accent,
                    ),
                  ),
                ),
              if (page != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: TextButton.icon(
                    onPressed: onNote,
                    icon: const Icon(Icons.menu_book_outlined, size: 12),
                    label: Text('صفحة $page'),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static int? _pageFromNote(String note) {
    final match = RegExp(r'صفحة\s+(\d+)').firstMatch(note);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}

class _OutlineView extends StatelessWidget {
  const _OutlineView({required this.map});

  final MindMap map;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        TrText(
          'المخطط ده بديل منظم للخريطة. كل فرع قابل للفتح والقفل.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        _OutlineBranch(node: map.root, depth: 0),
      ],
    );
  }
}

class _OutlineBranch extends StatelessWidget {
  const _OutlineBranch({required this.node, required this.depth});

  final MapNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: depth == 0
            ? theme.colorScheme.primary.withValues(alpha: 0.09)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            node.label,
            style: (depth == 0
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodySmall)
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (node.note.isNotEmpty)
            TrText(
              node.note,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
    if (node.children.isEmpty) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: depth == 0 ? 0 : 12),
        child: tile,
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth == 0 ? 0 : 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        initiallyExpanded: depth < 2,
        title: tile,
        children: [
          for (final child in node.children)
            _OutlineBranch(node: child, depth: depth + 1),
        ],
      ),
    );
  }
}

/// Tree geometry, computed for the current collapse state.
class _MapLayout {
  const _MapLayout({required this.nodes, required this.totalHeight});

  static const double nodeWidth = 220;

  /// Enough room for three label lines, two note lines and a 44px page
  /// button. [build] scales it with the system text scale.
  static const double baseNodeHeight = 132;

  static const double gap = 16;
  static const int maxDepth = 3;

  final List<_PlacedNode> nodes;
  final double totalHeight;

  static _MapLayout build(
    MapNode root,
    Set<String> collapsed, {
    double nodeHeight = baseNodeHeight,
  }) {
    final nodes = <_PlacedNode>[];
    var counter = 0;

    double measure(MapNode node, int depth) {
      if (depth >= maxDepth ||
          collapsed.contains(node.id) ||
          node.children.isEmpty) {
        return nodeHeight;
      }
      var total = 0.0;
      for (final child in node.children) {
        total += measure(child, depth + 1) + gap;
      }
      return math.max(nodeHeight, total - gap);
    }

    double place(MapNode node, int depth, double top, double height) {
      final center = top + height / 2;
      final left = 1420 - 110 - nodeWidth - depth * 330.0;
      nodes.add(
        _PlacedNode(
          node: node,
          depth: depth,
          left: math.max(8, left),
          top: center - nodeHeight / 2,
          centerY: center,
          centerX: math.max(8, left) + nodeWidth,
          order: counter++,
        ),
      );
      if (depth >= maxDepth ||
          collapsed.contains(node.id) ||
          node.children.isEmpty) {
        return center;
      }
      var childHeight = 0.0;
      for (final child in node.children) {
        childHeight += measure(child, depth + 1) + gap;
      }
      childHeight -= gap;
      var childTop = top + (height - childHeight) / 2;
      for (final child in node.children) {
        final h = measure(child, depth + 1);
        place(child, depth + 1, childTop, h);
        childTop += h + gap;
      }
      return center;
    }

    final rootHeight = measure(root, 0);
    place(root, 0, 0, rootHeight);
    final maxBottom = nodes.fold<double>(
      0,
      (value, node) => math.max(value, node.top + nodeHeight),
    );
    return _MapLayout(nodes: nodes, totalHeight: maxBottom);
  }
}

class _PlacedNode {
  const _PlacedNode({
    required this.node,
    required this.depth,
    required this.left,
    required this.top,
    required this.centerY,
    required this.centerX,
    required this.order,
  });

  final MapNode node;
  final int depth;

  /// Top-left of the node card.
  final double left;
  final double top;

  /// Anchor points for the connector.
  final double centerY;
  final double centerX;

  final int order;

  double get parentCenterX => centerX - _MapLayout.nodeWidth;
}

_MapLayout _layout(
  MapNode root,
  Set<String> collapsed, {
  double nodeHeight = _MapLayout.baseNodeHeight,
}) => _MapLayout.build(root, collapsed, nodeHeight: nodeHeight);

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.layout,
    required this.canvasHeight,
    required this.color,
  });

  final _MapLayout layout;
  final double canvasHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final byOrder = {for (final node in layout.nodes) node.order: node};
    final parentOf = <int, _PlacedNode>{};
    // The layout's positional order encodes the tree; walk it with a depth
    // stack to recover parent links without storing them on every node.
    final stack = <_PlacedNode>[];
    for (final node in layout.nodes) {
      while (stack.isNotEmpty && stack.last.depth >= node.depth) {
        stack.removeLast();
      }
      if (stack.isNotEmpty) parentOf[node.order] = stack.last;
      stack.add(node);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final node in layout.nodes) {
      final parent = parentOf[node.order];
      if (parent == null) continue;
      final start = Offset(parent.parentCenterX, parent.centerY);
      final end = Offset(node.centerX, node.centerY);
      final control = (parent.parentCenterX - end.dx).abs() * 0.55;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx - control,
          start.dy,
          end.dx + control,
          end.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, paint);
    }
    // Keep the map from collapsing to a hairline on very short trees.
    if (canvasHeight < 1) return;
    byOrder.clear();
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.canvasHeight != canvasHeight ||
      oldDelegate.color != color;
}
