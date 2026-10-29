/// The links pocket of one bag folder: lecture and revision links.
///
/// Only `http`/`https` links are ever stored, and they open in the browser
/// outside the app — the pocket just keeps them in order with a title.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization.dart';
import '../../../core/my_bag/my_bag_controller.dart';
import '../../../core/my_bag/my_bag_models.dart';
import '../../../core/theme.dart';
import '../../../providers/my_bag_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../../pdf/widgets/pdf_document_card.dart';

/// Opens a bag link outside the app; overridden in tests.
final bagLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class LinksPocketBody extends ConsumerWidget {
  const LinksPocketBody({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(myBagControllerProvider).mediaOf(folderId).links;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const TrText('روابط'),
            actions: [
              IconButton(
                key: const Key('bag-link-add'),
                tooltip: context.tr('أضف رابط'),
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add_link_rounded),
              ),
            ],
          ),
          if (links.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.link_rounded,
                title: 'مفيش روابط',
                message: 'ضيف رابط محاضرة أو مراجعة هنا.',
                action: FilledButton.icon(
                  onPressed: () => _add(context, ref),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const TrText('أضف رابط'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.sm),
              sliver: SliverList.builder(
                itemCount: links.length,
                itemBuilder: (context, index) => _LinkRow(
                  link: links[index],
                  onOpen: () => _open(context, ref, links[index]),
                  onEdit: () => _edit(context, ref, links[index]),
                  onDelete: () => _delete(context, ref, links[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    MyBagLink link,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(bagLinkLauncherProvider)(Uri.parse(link.url));
    } on Object {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('مقدرناش نفتح الرابط.')),
      );
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final current =
        ref.read(myBagControllerProvider).mediaOf(folderId).links.length;
    if (current >= kMaxLinks) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('حد أقصى 100 رابط في المجلد.')),
      );
      return;
    }
    final l10n = context.l10nOrNull;
    final draft = await showDialog<_LinkDraft>(
      context: context,
      builder: (dialogContext) => const _LinkDialog(),
    );
    if (draft == null) return;
    try {
      await ref
          .read(myBagControllerProvider.notifier)
          .addLink(folderId, title: draft.title, url: draft.url);
    } on ArgumentError catch (error) {
      // The explanation is in `message`; `invalidValue` is the URL itself.
      final reason = '${error.message ?? ''}';
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.t(reason) ?? reason)),
      );
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(content: TrText('حد أقصى 100 رابط في المجلد.')),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MyBagLink link,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10nOrNull;
    final draft = await showDialog<_LinkDraft>(
      context: context,
      builder: (dialogContext) => _LinkDialog(link: link),
    );
    if (draft == null) return;
    try {
      await ref
          .read(myBagControllerProvider.notifier)
          .updateLink(folderId, link.id, title: draft.title, url: draft.url);
    } on ArgumentError catch (error) {
      final reason = '${error.message ?? ''}';
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.t(reason) ?? reason)),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MyBagLink link,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: TrText(
          context.trf('حذف «{0}»؟', [link.title]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ZakerColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('احذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(myBagControllerProvider.notifier)
        .deleteLink(folderId, link.id);
  }
}

class _LinkDraft {
  const _LinkDraft({required this.title, required this.url});

  final String title;
  final String url;
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final MyBagLink link;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = '${bagLinkHost(link.url)} · '
        '${formatPdfDate(DateTime.fromMillisecondsSinceEpoch(link.createdAtMs))}';
    return ListTile(
      key: Key('bag-link-${link.id}'),
      leading: const Icon(Icons.link_rounded),
      title: Text(
        link.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        meta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onOpen,
      onLongPress: () => _showMenu(context),
      trailing: PopupMenuButton<String>(
        key: Key('bag-link-menu-${link.id}'),
        tooltip: context.tr('خيارات'),
        onSelected: (value) {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Text(context.tr('تعديل')),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(context.tr('حذف')),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const TrText('تعديل'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const TrText('حذف'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({this.link});

  final MyBagLink? link;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.link?.title ?? '',
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.link?.url ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final url = _url.text.trim();
    final error = validateBagLinkUrl(url);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_LinkDraft(title: _title.text.trim(), url: url));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adding = widget.link == null;
    return AlertDialog(
      title: TrText(adding ? 'رابط جديد' : 'تعديل الرابط'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('bag-link-title'),
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: context.tr('العنوان')),
          ),
          const SizedBox(height: ZakerSpacing.md),
          TextField(
            key: const Key('bag-link-url'),
            controller: _url,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            autofocus: adding,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(labelText: context.tr('الرابط')),
          ),
          if (_error != null) ...[
            const SizedBox(height: ZakerSpacing.sm),
            Text(
              context.tr(_error!),
              key: const Key('bag-link-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZakerColors.danger,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        TextButton(
          key: const Key('bag-link-save'),
          onPressed: _save,
          child: const TrText('حفظ'),
        ),
      ],
    );
  }
}
