/// The local batch chat: text, voice notes, replies, reactions and pins.
///
/// Everything here is real local state. There is no online presence, no
/// delivery tick and no moderation server; those appear as blocked states.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/audio_playback_controller.dart';
import '../../../core/batches/audio_recorder_channel.dart';
import '../../../core/batches/batch_access.dart';
import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/batches/chat_store.dart';
import '../../../core/theme.dart';
import '../../../models/batch.dart';
import '../../../models/batch_chat.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import 'chat_controller.dart';
import 'voice_note_recorder.dart';

class BatchChatScreen extends ConsumerStatefulWidget {
  const BatchChatScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchChatScreen> createState() => _BatchChatScreenState();
}

class _BatchChatScreenState extends ConsumerState<BatchChatScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final Set<String> _expanded = {};

  ChatMessage? _replyTo;
  RecordedClip? _pendingClip;
  DateTime? _seenBefore;
  bool _pinsHidden = false;
  bool _sending = false;
  bool _showJump = false;

  ChatController get _chat =>
      ref.read(chatControllerProvider(widget.batchId).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final uid = ref.read(authUserProvider)?.uid ?? '';
    if (uid.isNotEmpty) {
      final seen = ref.read(chatSeenStoreProvider);
      _seenBefore = seen.seenAt(uid: uid, batchId: widget.batchId);
      unawaited(
        seen
            .markSeen(
              uid: uid,
              batchId: widget.batchId,
              at: DateTime.now(),
            )
            .catchError((Object _) {}),
      );
    }
    Future<void>.microtask(() => _chat.loadInitial());
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final showJump = position.pixels > 160;
    if (showJump != _showJump) setState(() => _showJump = showJump);
    if (position.pixels >= position.maxScrollExtent - 160) {
      unawaited(_chat.loadOlder());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _inputFocus.dispose();
    final pending = _pendingClip;
    if (pending != null) {
      try {
        final file = File(pending.path);
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // The platform cache owns the abandoned temporary file.
      }
    }
    super.dispose();
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.batchId));
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final user = ref.watch(authUserProvider);
    final uid = user?.uid ?? '';
    final snapshot = detail.valueOrNull;
    final membership = snapshot == null ? null : _membershipOf(snapshot, uid);
    final role = membership?.role;
    final canSend =
        role != null && BatchAccess.can(role, BatchAction.sendMessage);
    final canPin =
        role != null && BatchAccess.can(role, BatchAction.pinMessage);

    final pinned = [
      for (final message in state.messages)
        if (message.pinned && !message.isDeleted) message,
    ];
    final firstUnread = _firstUnreadId(state.messages, uid);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('المحادثة'),
        actions: [
          IconButton(
            tooltip: 'عن المحادثة',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          const _HeaderNote(),
          if (pinned.isNotEmpty && !_pinsHidden)
            _PinnedStrip(
              messages: pinned,
              onClose: () => setState(() => _pinsHidden = true),
            ),
          Expanded(
            child: Stack(
              children: [
                _messageArea(state, uid, canPin, firstUnread),
                if (_showJump)
                  PositionedDirectional(
                    end: ZakerSpacing.lg,
                    bottom: ZakerSpacing.lg,
                    child: FloatingActionButton.small(
                      tooltip: 'روح لأحدث رسالة',
                      onPressed: _jumpToLatest,
                      child: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ),
              ],
            ),
          ),
          if (detail.hasError)
            _ComposerNotice(
              icon: Icons.error_outline_rounded,
              text: 'مقدرناش نتحقق من صلاحياتك في الدفعة. '
                  'المحادثة للقراءة بس.',
              error: true,
            )
          else if (!canSend && detail.hasValue)
            _ComposerNotice(
              icon: Icons.lock_outline_rounded,
              text: 'مش مسموح لك تكتب في المحادثة دي. تقدر تقرا بس.',
              error: false,
            )
          else
            _Composer(
              controller: _input,
              focusNode: _inputFocus,
              sending: _sending,
              replyTo: _replyTo,
              onChanged: () => setState(() {}),
              onCancelReply: () => setState(() => _replyTo = null),
              onSend: _sendText,
              onRecord: _recordVoice,
            ),
        ],
      ),
    );
  }

  Widget _messageArea(
    ChatState state,
    String uid,
    bool canPin,
    String? firstUnread,
  ) {
    if (state.loading && !state.initialized) {
      return const Center(child: LoadingBox(label: 'بنقرا المحادثة…'));
    }
    if (!state.initialized && state.failure != null) {
      return _ChatError(
        failure: state.failure!,
        onRetry: () => _chat.retry(),
      );
    }
    if (state.messages.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'لسه مفيش رسائل',
        message: 'اكتب أول رسالة. المحادثة بتتحفظ على الجهاز ده بس.',
      );
    }
    final messages = state.messages;
    final count = messages.length + (state.hasMore ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.md,
        ZakerSpacing.md,
        ZakerSpacing.md,
        ZakerSpacing.md,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _OlderLoader(
            loading: state.loadingOlder,
            onTap: () => _chat.loadOlder(),
          );
        }
        final position = messages.length - 1 - index;
        final message = messages[position];
        final previous = position > 0 ? messages[position - 1] : null;
        final showDate = previous == null ||
            !_sameDay(previous.createdAt, message.createdAt);
        ChatMessage? parent;
        final replyId = message.replyToId;
        if (replyId != null) {
          for (final item in messages) {
            if (item.id == replyId) {
              parent = item;
              break;
            }
          }
        }
        final canDelete = _canDelete(message, uid);
        return Column(
          key: ValueKey(message.id),
          children: [
            if (showDate) _DateSeparator(date: message.createdAt),
            if (message.id == firstUnread) const _UnreadDivider(),
            _MessageTile(
              batchId: widget.batchId,
              message: message,
              parent: parent,
              uid: uid,
              canPin: canPin,
              canDelete: canDelete,
              expanded: _expanded.contains(message.id),
              onToggleExpand: () {
                setState(() {
                  if (!_expanded.remove(message.id)) {
                    _expanded.add(message.id);
                  }
                });
              },
              onAction: (action) => _handleAction(action, message),
              onReact: (emoji) => _react(message, emoji),
            ),
          ],
        );
      },
    );
  }

  bool _canDelete(ChatMessage message, String uid) {
    final snapshot = ref.read(batchDetailProvider(widget.batchId)).valueOrNull;
    if (snapshot == null) return false;
    final membership = _membershipOf(snapshot, uid);
    if (membership == null) return false;
    return BatchAccess.can(
      membership.role,
      message.authorUid == uid
          ? BatchAction.deleteOwnMessage
          : BatchAction.deleteAnyMessage,
    );
  }

  String? _firstUnreadId(List<ChatMessage> messages, String uid) {
    final seen = _seenBefore;
    if (seen == null) return null;
    for (final message in messages) {
      if (message.authorUid != uid && message.createdAt.isAfter(seen)) {
        return message.id;
      }
    }
    return null;
  }

  static Membership? _membershipOf(BatchSnapshot snapshot, String uid) {
    for (final member in snapshot.members) {
      if (member.uid == uid) return member;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(authUserProvider);
    if (user == null) return;
    final replyId = _replyTo?.id;
    setState(() => _sending = true);
    try {
      await _chat.sendText(
        text: text,
        authorName: user.displayName,
        replyToId: replyId,
      );
      if (!mounted) return;
      _input.clear();
      setState(() => _replyTo = null);
      _jumpToLatest();
    } on BatchFailure catch (failure) {
      if (mounted) _snack(batchErrorText(failure));
    } on Object {
      if (mounted) _snack('مقدرناش نحفظ الرسالة على الجهاز.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recordVoice() async {
    if (_sending) return;
    final clip = await showModalBottomSheet<RecordedClip>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) => const VoiceNoteRecorder(),
    );
    if (clip == null || !mounted) return;
    await _sendClip(clip, _replyTo?.id);
  }

  Future<void> _sendClip(RecordedClip clip, String? replyToId) async {
    if (!mounted || _sending) return;
    final user = ref.read(authUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await _chat.sendVoice(
        tempPath: clip.path,
        durationMs: clip.durationMs,
        authorName: user.displayName,
        replyToId: replyToId,
      );
      _pendingClip = null;
      if (!mounted) return;
      setState(() => _replyTo = null);
      _jumpToLatest();
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      _pendingClip = clip;
      _snack(
        batchErrorText(failure),
        action: SnackBarAction(
          label: 'جرّب تاني',
          onPressed: () => _sendClip(clip, replyToId),
        ),
      );
    } on Object {
      if (!mounted) return;
      _pendingClip = clip;
      _snack(
        'مقدرناش نحفظ الرسالة الصوتية.',
        action: SnackBarAction(
          label: 'جرّب تاني',
          onPressed: () => _sendClip(clip, replyToId),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleAction(_MessageAction action, ChatMessage message) async {
    switch (action) {
      case _MessageAction.reply:
        setState(() => _replyTo = message);
        _inputFocus.requestFocus();
      case _MessageAction.react:
        await _showReactionPalette(message);
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        _snack('اتنسخ النص.');
      case _MessageAction.edit:
        await _editMessage(message);
      case _MessageAction.pin:
      case _MessageAction.unpin:
        await _setPinned(message, action == _MessageAction.pin);
      case _MessageAction.delete:
        await _deleteMessage(message);
      case _MessageAction.report:
        await _showReportBlocked();
    }
  }

  Future<void> _showReactionPalette(ChatMessage message) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            ZakerSpacing.sm,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: ZakerSpacing.md,
            runSpacing: ZakerSpacing.md,
            children: [
              for (final value in ChatStore.reactions)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(sheetContext).pop(value),
                  child: Padding(
                    padding: const EdgeInsets.all(ZakerSpacing.sm),
                    child: Text(value, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null || !mounted) return;
    await _react(message, emoji);
  }

  Future<void> _react(ChatMessage message, String emoji) async {
    try {
      await _chat.toggleReaction(message, emoji);
    } on BatchFailure catch (failure) {
      _snack(batchErrorText(failure));
    } on Object {
      _snack('مقدرناش نحفظ التفاعل.');
    }
  }

  Future<void> _setPinned(ChatMessage message, bool pinned) async {
    try {
      await _chat.setPinned(message, pinned);
      _snack(pinned ? 'الرسالة اتثبتت.' : 'التثبيت اتشال.');
    } on BatchFailure catch (failure) {
      _snack(batchErrorText(failure));
    } on Object {
      _snack('مقدرناش نغيّر التثبيت.');
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EditMessageDialog(initial: message.text),
    );
    if (text == null || !mounted) return;
    try {
      await _chat.editMessage(message.id, text);
    } on BatchFailure catch (failure) {
      _snack(batchErrorText(failure));
    } on Object {
      _snack('مقدرناش نعدّل الرسالة.');
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف الرسالة؟'),
        content: const TrText(
          'هيتم مسح نص الرسالة وأي تسجيل صوتي من جهازك، وهتفضل علامة '
          'إن الرسالة اتشالت. مفيش نسخة على سيرفر ترجعها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _chat.deleteMessage(message.id);
      _snack('الرسالة اتشالت.');
    } on BatchFailure catch (failure) {
      _snack(batchErrorText(failure));
    } on Object {
      _snack('مقدرناش نحذف الرسالة.');
    }
  }

  Future<void> _showReportBlocked() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('الإبلاغ مش متاح'),
        content: const TrText(
          'الإبلاغ والحظر محتاجين سيرفر إشراف. المحادثة دي على جهازك بس، '
          'ومفيش حاجة اتبعتت بره الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const TrText('تمام'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelp() {
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
                'عن المحادثة',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              const _HelpLine(
                icon: Icons.phonelink_lock_rounded,
                text: 'الرسائل والتسجيلات الصوتية محفوظة في مساحة خاصة '
                    'بحسابك على الجهاز ده.',
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const _HelpLine(
                icon: Icons.cloud_off_rounded,
                text: 'توصيل الرسائل للأعضاء التانيين لحظيًا محتاج سيرفر، '
                    'ومفيش إشعارات فورية.',
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const _HelpLine(
                icon: Icons.subtitles_off_outlined,
                text: 'تفريغ الرسائل الصوتية غير متاح محليًا. مفيش نصوص '
                    'وهمية ولا رفع لمزوّد خارجي.',
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

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: TrText(message), action: action),
    );
  }
}

enum _MessageAction { reply, react, copy, edit, pin, unpin, delete, report }

class _HeaderNote extends StatelessWidget {
  const _HeaderNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.lg,
        vertical: ZakerSpacing.sm,
      ),
      color: theme.colorScheme.primary.withValues(alpha: 0.07),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phonelink_lock_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TrText(
              'محادثة محفوظة على الجهاز — توصيل الرسائل للأعضاء التانيين '
              'محتاج سيرفر.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedStrip extends StatelessWidget {
  const _PinnedStrip({required this.messages, required this.onClose});

  final List<ChatMessage> messages;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ZakerSpacing.lg,
        ZakerSpacing.xs,
        ZakerSpacing.xs,
        ZakerSpacing.xs,
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.push_pin_rounded,
            size: 16,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final message in messages)
                  TrText(
                    '${message.authorName}: ${_snippet(message)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(height: 1.6),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إخفاء المثبت',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  static String _snippet(ChatMessage message) =>
      message.kind == ChatMessageKind.voice ? 'رسالة صوتية' : message.text;
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.primary)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.sm),
            child: TrText(
              'رسائل جديدة',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: TrText(
            _label(date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  static String _label(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'اليوم';
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    return formatBatchDate(value);
  }
}

class _MessageTile extends ConsumerWidget {
  const _MessageTile({
    required this.batchId,
    required this.message,
    required this.parent,
    required this.uid,
    required this.canPin,
    required this.canDelete,
    required this.expanded,
    required this.onToggleExpand,
    required this.onAction,
    required this.onReact,
  });

  final String batchId;
  final ChatMessage message;
  final ChatMessage? parent;
  final String uid;
  final bool canPin;
  final bool canDelete;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final Future<void> Function(_MessageAction action) onAction;
  final Future<void> Function(String emoji) onReact;

  bool get _mine => message.authorUid == uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deleted = message.isDeleted;
    final bubbleColor = deleted
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : _mine
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.cardTheme.color;
    final longText = !deleted &&
        message.kind == ChatMessageKind.text &&
        (message.text.runes.length > 320 ||
            '\n'.allMatches(message.text).length > 3);

    return Align(
      alignment: _mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
        padding: const EdgeInsetsDirectional.fromSTEB(
          ZakerSpacing.md,
          ZakerSpacing.sm,
          ZakerSpacing.sm,
          ZakerSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(ZakerRadius.md),
            topEnd: const Radius.circular(ZakerRadius.md),
            bottomStart: Radius.circular(_mine ? ZakerRadius.md : 4),
            bottomEnd: Radius.circular(_mine ? 4 : ZakerRadius.md),
          ),
          border: Border.all(
            color: deleted
                ? theme.dividerTheme.color ?? Colors.black12
                : theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: TrText(
                    message.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _mine
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _timeLabel(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (message.pinned)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 12,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
            if (message.replyToId != null) ...[
              const SizedBox(height: 4),
              _ReplyPreview(parent: parent),
            ],
            const SizedBox(height: 4),
            if (deleted)
              TrText(
                'الرسالة اتشالت',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (message.kind == ChatMessageKind.voice)
              _VoiceBubble(batchId: batchId, message: message)
            else ...[
              TrText(
                message.text,
                maxLines: expanded || !longText ? null : 6,
                overflow: expanded || !longText ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              if (longText)
                GestureDetector(
                  onTap: onToggleExpand,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: TrText(
                      expanded ? 'اقرأ أقل' : 'اقرأ المزيد',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
            if (message.editedAt != null && !deleted)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: TrText(
                  'اتعدّلت',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final entry in message.reactions.entries)
                    _ReactionChip(
                      emoji: entry.key,
                      count: entry.value.length,
                      mine: entry.value.contains(uid),
                      onTap: () => onReact(entry.key),
                    ),
                ],
              ),
            ],
            if (!deleted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تفاعل',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showPalette(context),
                    icon: const Icon(Icons.add_reaction_outlined, size: 16),
                  ),
                  if (canPin)
                    IconButton(
                      tooltip: message.pinned ? 'شيل التثبيت' : 'ثبّت',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onAction(
                        message.pinned
                            ? _MessageAction.unpin
                            : _MessageAction.pin,
                      ),
                      icon: Icon(
                        message.pinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                        size: 16,
                      ),
                    ),
                  IconButton(
                    tooltip: 'خيارات الرسالة',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showMenu(context),
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPalette(BuildContext context) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            ZakerSpacing.sm,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: ZakerSpacing.md,
            runSpacing: ZakerSpacing.md,
            children: [
              for (final value in ChatStore.reactions)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(sheetContext).pop(value),
                  child: Padding(
                    padding: const EdgeInsets.all(ZakerSpacing.sm),
                    child: Text(value, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null) return;
    await onReact(emoji);
  }

  Future<void> _showMenu(BuildContext context) async {
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                0,
                ZakerSpacing.lg,
                ZakerSpacing.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TrText(
                  'الرسالة',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.reply_rounded,
              label: 'رد',
              onTap: () => Navigator.of(sheetContext).pop(_MessageAction.reply),
            ),
            if (message.kind == ChatMessageKind.text)
              _ActionTile(
                icon: Icons.copy_rounded,
                label: 'انسخ النص',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_MessageAction.copy),
              ),
            if (_mine && message.kind == ChatMessageKind.text)
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'عدّل',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_MessageAction.edit),
              ),
            _ActionTile(
              icon: Icons.flag_outlined,
              label: 'إبلاغ',
              onTap: () =>
                  Navigator.of(sheetContext).pop(_MessageAction.report),
            ),
            if (canDelete)
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'احذف',
                destructive: true,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_MessageAction.delete),
              ),
            const SizedBox(height: ZakerSpacing.sm),
          ],
        ),
      ),
    );
    if (action == null) return;
    await onAction(action);
  }

  static String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = arabicDigits(local.minute).padLeft(2, '٠');
    final suffix = local.hour < 12 ? 'ص' : 'م';
    return '${arabicDigits(hour)}:$minute $suffix';
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.parent});

  final ChatMessage? parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parentValue = parent;
    final label = parentValue == null
        ? 'رسالة سابقة'
        : parentValue.isDeleted
            ? 'الرسالة اتشالت'
            : parentValue.kind == ChatMessageKind.voice
                ? 'رسالة صوتية'
                : parentValue.text;
    final author = parentValue == null || parentValue.isDeleted
        ? ''
        : '${parentValue.authorName}: ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        border: BorderDirectional(
          start: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      child: TrText(
        '$author$label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.cardTheme.color ?? theme.colorScheme.surface;
    // Paint the translucent chip over its real backdrop so the count can be
    // darkened until it reads at 4.5:1.
    final background = mine
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.14),
            base,
          )
        : Color.alphaBlend(
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            base,
          );
    return Semantics(
      button: true,
      selected: mine,
      label: 'تفاعل $emoji، ${arabicDigits(count)}، '
          '${mine ? 'من ضمنهم انت' : 'لسه ماضفتوش'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: mine
                  ? theme.colorScheme.primary
                  : theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                arabicDigits(count),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: mine
                      ? readableTextColor(
                          theme.colorScheme.primary,
                          background,
                        )
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceBubble extends ConsumerWidget {
  const _VoiceBubble({required this.batchId, required this.message});

  final String batchId;
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final path = ChatStore.voicePath(message.id);
    final missing = ref
            .watch(
              resourceMissingProvider(
                (batchId: batchId, relativePath: path),
              ),
            )
            .valueOrNull ??
        false;
    final duration = message.voiceDurationMs ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(ZakerRadius.sm),
      onTap: missing
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => _VoiceSheet(
                  batchId: batchId,
                  message: message,
                ),
              ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            missing ? Icons.volume_off_rounded : Icons.play_circle_fill_rounded,
            size: 30,
            color:
                missing ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                duration > 0 ? formatDuration(duration) : 'رسالة صوتية',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TrText(
                missing ? 'التسجيل مش موجود على الجهاز' : 'دوس للاستماع',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: missing
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceSheet extends ConsumerStatefulWidget {
  const _VoiceSheet({required this.batchId, required this.message});

  final String batchId;
  final ChatMessage message;

  @override
  ConsumerState<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends ConsumerState<_VoiceSheet> {
  late final AudioPlaybackController _controller;

  /// This sheet's own native player, keyed by the message it plays.
  String get _clientId => 'chat-${widget.message.id}';

  @override
  void initState() {
    super.initState();
    final uid = ref.read(authUserProvider)?.uid ?? '';
    final path = ref
        .read(batchFileStoreProvider)
        .fileInBatch(
          uid,
          widget.batchId,
          ChatStore.voicePath(widget.message.id),
        )
        .path;
    _controller = AudioPlaybackController(
      bindings: ref.read(audioPlayerBindingsProvider(_clientId)),
      positions: ref.read(playbackPositionStoreProvider),
      uid: uid,
      batchId: widget.batchId,
      resourceId: widget.message.id,
      path: path,
      knownDurationMs: widget.message.voiceDurationMs,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps this sheet's player alive until it closes; the provider
    // then releases exactly this client's native player.
    ref.watch(audioPlayerBindingsProvider(_clientId));
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          0,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final duration = _controller.durationMs;
            final position = _controller.positionMs
                .clamp(0, duration > 0 ? duration : 0)
                .toInt();
            final ready = _controller.isReady;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    Expanded(
                      child: TrText(
                        'رسالة صوتية من ${widget.message.authorName}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (_controller.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ZakerSpacing.md,
                    ),
                    child: TrText(
                      'التسجيل مش مقروء على الجهاز.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  )
                else ...[
                  Slider(
                    value: duration > 0 ? position.toDouble() : 0,
                    max: duration > 0 ? duration.toDouble() : 1,
                    onChanged: ready
                        ? (value) => _controller.seekTo(value.round())
                        : null,
                  ),
                  Row(
                    children: [
                      Text(
                        formatDuration(position),
                        style: theme.textTheme.labelSmall,
                      ),
                      const Spacer(),
                      Text(
                        duration > 0
                            ? formatDuration(duration)
                            : 'المدة لسه مش معروفة',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZakerSpacing.sm),
                  FilledButton.icon(
                    onPressed: ready ? _controller.toggle : null,
                    icon: Icon(
                      _controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: TrText(
                      _controller.isPlaying ? 'وقف مؤقت' : 'شغّل',
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OlderLoader extends StatelessWidget {
  const _OlderLoader({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.md),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const TrText('حمّل الرسائل الأقدم'),
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.replyTo,
    required this.onChanged,
    required this.onCancelReply,
    required this.onSend,
    required this.onRecord,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ChatMessage? replyTo;
  final VoidCallback onChanged;
  final VoidCallback onCancelReply;
  final Future<void> Function() onSend;
  final Future<void> Function() onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sending) const LinearProgressIndicator(minHeight: 2),
            if (replyTo != null)
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ZakerSpacing.md,
                  ZakerSpacing.xs,
                  ZakerSpacing.xs,
                  ZakerSpacing.xs,
                ),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TrText(
                        'رد على ${replyTo!.authorName}: '
                        '${replyTo!.kind == ChatMessageKind.voice ? 'رسالة صوتية' : replyTo!.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'إلغاء الرد',
                      visualDensity: VisualDensity.compact,
                      onPressed: onCancelReply,
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.sm,
                ZakerSpacing.sm,
                ZakerSpacing.sm,
                ZakerSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'رسالة صوتية',
                    onPressed: sending ? null : onRecord,
                    icon: const Icon(Icons.mic_none_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZakerSpacing.xs),
                  IconButton.filled(
                    tooltip: 'إرسال',
                    onPressed: sending || controller.text.trim().isEmpty
                        ? null
                        : onSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({
    required this.icon,
    required this.text,
    required this.error,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: error ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: error
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: TrText(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initial});

  final String initial;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'اكتب نص الرسالة.');
      return;
    }
    if (text.runes.length > ChatStore.maxTextChars) {
      setState(() => _error = 'الرسالة أطول من الحد.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TrText('عدّل الرسالة'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: 'نص الرسالة',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const TrText('حفظ'),
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

class _ChatError extends StatelessWidget {
  const _ChatError({required this.failure, required this.onRetry});

  final BatchFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(batchErrorText(failure), textAlign: TextAlign.center),
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
