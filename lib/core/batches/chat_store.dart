/// Durable local chat: append, edit, tombstone, reactions and pins.
///
/// Authorization lives in the repository; this store only guards the document
/// invariants. Every command rewrites `chat/main.json` atomically, so a
/// malformed message can never enter the history and a retry with the same
/// client key cannot duplicate one.
library;

import 'dart:io';

import '../../models/batch_chat.dart';
import 'batch_failure.dart';
import 'batch_store.dart';

class ChatStore {
  ChatStore({
    required this.directory,
    DateTime Function()? clock,
    this.pageSize = 30,
  }) : _clock = clock ?? DateTime.now;

  final Directory directory;
  final DateTime Function() _clock;

  /// The UI shows at most this many messages per page.
  final int pageSize;

  static const int maxPageSize = 30;
  static const int maxTextChars = 4000;
  static const int maxClientKeyChars = 64;
  static const int maxVoiceMs = 15 * 60 * 1000;

  /// The reaction palette the composer offers. Unknown emoji are refused so a
  /// crafted string cannot become a rendering or storage problem.
  static const Set<String> reactions = {
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  };

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final RegExp _clientKeyPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  /// The private copy of a voice note, keyed by its message id.
  static String voicePath(String messageId) => 'chat/voice/$messageId.m4a';

  BatchStore get _batch => BatchStore(directory: directory);

  /// Messages ordered oldest first. Throws when the document is unreadable,
  /// so a command never replaces a corrupt history with a short new one.
  Future<List<ChatMessage>> _load() async {
    final load = await _batch.chat.load();
    if (load.isMissing) return [];
    if (!load.isUsable) {
      throw load.failure ??
          const BatchFailure(BatchFailureCode.corruptStore, detail: 'chat');
    }
    final messages = [...load.value!];
    messages.sort(_compare);
    return messages;
  }

  Future<void> _save(List<ChatMessage> messages) async {
    final ordered = [...messages]..sort(_compare);
    await _batch.chat.save(ordered);
  }

  static int _compare(ChatMessage a, ChatMessage b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  /// The newest messages older than [before].
  Future<ChatPage> page({ChatCursor? before, int? limit}) async {
    final size = (limit ?? pageSize).clamp(1, maxPageSize);
    final all = await _load();
    final eligible = before == null
        ? all
        : all
            .where((message) =>
                ChatCursor(createdAt: message.createdAt, id: message.id)
                    .compareTo(before) <
                0)
            .toList();
    final hasMore = eligible.length > size;
    final messages = hasMore
        ? eligible.sublist(eligible.length - size)
        : eligible;
    return ChatPage(messages: messages, hasMore: hasMore);
  }

  Future<ChatMessage?> find(String messageId) async {
    for (final message in await _load()) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  /// Appends [message].
  ///
  /// A repeated client key returns the message already stored instead of
  /// writing a duplicate, which is what makes a failed-looking retry safe.
  Future<ChatMessage> append(ChatMessage message) async {
    _validateForAppend(message);
    final clean = message.kind == ChatMessageKind.text
        ? message.copyWith(text: _cleanText(message.text))
        : message;
    final messages = await _load();
    for (final existing in messages) {
      if (existing.clientKey.isNotEmpty &&
          existing.clientKey == clean.clientKey) {
        return existing;
      }
      if (existing.id == clean.id) {
        throw const BatchFailure(BatchFailureCode.conflict, field: 'messageId');
      }
    }
    if (clean.replyToId != null &&
        !messages.any((item) => item.id == clean.replyToId)) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'replyToId');
    }
    messages.add(clean);
    await _save(messages);
    return clean;
  }

  Future<ChatMessage> edit(String messageId, String text) async {
    final messages = await _load();
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final message = messages[index];
    if (message.isDeleted || message.kind != ChatMessageKind.text) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'messageId',
      );
    }
    final clean = _cleanText(text);
    final updated = message.copyWith(text: clean, editedAt: _clock());
    messages[index] = updated;
    await _save(messages);
    return updated;
  }

  /// Leaves a tombstone; the text and any voice file reference are cleared.
  Future<ChatMessage> delete(String messageId) async {
    final messages = await _load();
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final message = messages[index];
    if (message.isDeleted) return message;
    final tombstone = ChatMessage(
      id: message.id,
      batchId: message.batchId,
      channelId: message.channelId,
      authorUid: message.authorUid,
      authorName: message.authorName,
      kind: message.kind,
      createdAt: message.createdAt,
      replyToId: message.replyToId,
      editedAt: message.editedAt,
      deletedAt: _clock(),
      clientKey: message.clientKey,
    );
    messages[index] = tombstone;
    await _save(messages);
    return tombstone;
  }

  /// Adds or removes [uid] from [emoji] on one message.
  Future<ChatMessage> react(
    String messageId,
    String emoji,
    String uid,
    bool reacted,
  ) async {
    if (!reactions.contains(emoji)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'emoji',
      );
    }
    if (uid.isEmpty) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'uid',
      );
    }
    final messages = await _load();
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final message = messages[index];
    if (message.isDeleted) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final byEmoji = {
      for (final entry in message.reactions.entries) entry.key: {...entry.value},
    };
    final uids = byEmoji.putIfAbsent(emoji, () => <String>{});
    if (reacted) {
      uids.add(uid);
    } else {
      uids.remove(uid);
    }
    if (uids.isEmpty) byEmoji.remove(emoji);
    final updated = message.copyWith(reactions: byEmoji);
    messages[index] = updated;
    await _save(messages);
    return updated;
  }

  Future<ChatMessage> setPinned(String messageId, bool pinned) async {
    final messages = await _load();
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final message = messages[index];
    if (message.isDeleted) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final updated = message.copyWith(pinned: pinned);
    messages[index] = updated;
    await _save(messages);
    return updated;
  }

  void _validateForAppend(ChatMessage message) {
    if (!_idPattern.hasMatch(message.id) ||
        !_idPattern.hasMatch(message.batchId) ||
        message.channelId != 'main' ||
        message.authorUid.isEmpty ||
        message.authorName.trim().isEmpty ||
        message.authorName.runes.length > 80 ||
        !_clientKeyPattern.hasMatch(message.clientKey)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'message',
      );
    }
    switch (message.kind) {
      case ChatMessageKind.text:
        _cleanText(message.text);
      case ChatMessageKind.voice:
        final name = message.voiceFileName.trim();
        final duration = message.voiceDurationMs ?? 0;
        if (name.isEmpty ||
            !name.toLowerCase().endsWith('.m4a') ||
            duration <= 0 ||
            duration > maxVoiceMs) {
          throw const BatchFailure(
            BatchFailureCode.validationFailed,
            field: 'voice',
          );
        }
    }
  }

  String _cleanText(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty ||
        clean.runes.length > maxTextChars ||
        clean.runes.any((rune) =>
            (rune < 0x20 && rune != 0x0A && rune != 0x09) || rune == 0x7F)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'text',
      );
    }
    return clean;
  }
}
