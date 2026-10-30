/// Paged chat state and commands for one batch channel.
///
/// The controller keeps the newest page in memory and asks the repository for
/// older pages by cursor. Authorization, tombstones and the audit trail all
/// stay in the repository; this class only shapes what the screen shows.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_file_store.dart';
import '../../../core/batches/batch_ids.dart';
import '../../../core/batches/batch_repository.dart';
import '../../../core/batches/chat_store.dart';
import '../../../models/batch_chat.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.hasMore = false,
    this.loading = false,
    this.loadingOlder = false,
    this.initialized = false,
    this.failure,
  });

  /// Oldest first, so `ListView` can append at the end without reversing.
  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loading;
  final bool loadingOlder;
  final bool initialized;
  final BatchFailure? failure;

  bool get isEmpty => initialized && messages.isEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loading,
    bool? loadingOlder,
    bool? initialized,
    BatchFailure? failure,
    bool clearFailure = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        initialized: initialized ?? this.initialized,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required this.repository,
    required this.files,
    required this.uid,
    required this.batchId,
    DateTime Function()? clock,
    String Function(String prefix)? newId,
  })  : _clock = clock ?? DateTime.now,
        _newId = newId ?? newEntityId,
        super(const ChatState());

  final BatchRepository repository;
  final BatchFileStore files;
  final String uid;
  final String batchId;
  final DateTime Function() _clock;
  final String Function(String prefix) _newId;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadInitial() async {
    if (state.loading || state.initialized) return;
    _emit(state.copyWith(loading: true, clearFailure: true));
    try {
      final page = await repository.loadChat(uid, batchId);
      if (_disposed) return;
      _emit(
        state.copyWith(
          messages: page.messages,
          hasMore: page.hasMore,
          loading: false,
          initialized: true,
          clearFailure: true,
        ),
      );
    } on BatchFailure catch (failure) {
      if (_disposed) return;
      _emit(state.copyWith(loading: false, failure: failure));
    }
  }

  Future<void> retry() async {
    _emit(const ChatState());
    await loadInitial();
  }

  Future<void> loadOlder() async {
    final current = state;
    if (!current.hasMore ||
        current.loadingOlder ||
        current.messages.isEmpty ||
        _disposed) {
      return;
    }
    _emit(current.copyWith(loadingOlder: true, clearFailure: true));
    final oldest = current.messages.first;
    try {
      final page = await repository.loadChat(
        uid,
        batchId,
        before: ChatCursor(createdAt: oldest.createdAt, id: oldest.id),
      );
      if (_disposed) return;
      _emit(
        state.copyWith(
          messages: [...page.messages, ...state.messages],
          hasMore: page.hasMore,
          loadingOlder: false,
        ),
      );
    } on BatchFailure catch (failure) {
      if (_disposed) return;
      _emit(state.copyWith(loadingOlder: false, failure: failure));
    }
  }

  /// Sends a text message and returns the stored one.
  Future<ChatMessage> sendText({
    required String text,
    required String authorName,
    String? replyToId,
  }) {
    final message = ChatMessage(
      id: _newId('msg'),
      batchId: batchId,
      channelId: 'main',
      authorUid: uid,
      authorName: authorName.trim(),
      kind: ChatMessageKind.text,
      text: text,
      replyToId: replyToId,
      createdAt: _clock(),
      clientKey: _newId('key'),
    );
    return _send(message);
  }

  /// Copies the finished temporary recording into the batch, then indexes it.
  ///
  /// The private copy is removed again when the message cannot be stored, so
  /// a denied or failed send leaves no orphan file.
  Future<ChatMessage> sendVoice({
    required String tempPath,
    required int durationMs,
    required String authorName,
    String? replyToId,
  }) async {
    final id = _newId('msg');
    final relativePath = ChatStore.voicePath(id);
    await files.copyFile(
      uid: uid,
      batchId: batchId,
      relativePath: relativePath,
      sourcePath: tempPath,
    );
    final message = ChatMessage(
      id: id,
      batchId: batchId,
      channelId: 'main',
      authorUid: uid,
      authorName: authorName.trim(),
      kind: ChatMessageKind.voice,
      voiceFileName: '$id.m4a',
      voiceDurationMs: durationMs,
      replyToId: replyToId,
      createdAt: _clock(),
      clientKey: _newId('key'),
    );
    try {
      final saved = await _send(message);
      _deleteTemp(tempPath);
      return saved;
    } catch (error) {
      try {
        await files.deleteFile(
          uid: uid,
          batchId: batchId,
          relativePath: relativePath,
        );
      } on BatchFailure {
        // The failed copy is best-effort cleanup.
      }
      // The temporary recording is left in place so the screen can offer a
      // retry; it deletes the file itself when the retry is abandoned.
      rethrow;
    }
  }

  Future<ChatMessage> editMessage(String messageId, String text) async {
    final updated = await repository.editChatMessage(
      uid,
      batchId,
      messageId,
      text,
    );
    _replace(updated);
    return updated;
  }

  Future<ChatMessage> deleteMessage(String messageId) async {
    final updated = await repository.deleteChatMessage(uid, batchId, messageId);
    _replace(updated);
    return updated;
  }

  Future<ChatMessage> toggleReaction(
    ChatMessage message,
    String emoji,
  ) async {
    final reacted = message.reactions[emoji]?.contains(uid) ?? false;
    final updated = await repository.reactToChatMessage(
      uid,
      batchId,
      message.id,
      emoji,
      !reacted,
    );
    _replace(updated);
    return updated;
  }

  Future<ChatMessage> setPinned(ChatMessage message, bool pinned) async {
    final updated = await repository.pinChatMessage(
      uid,
      batchId,
      message.id,
      pinned,
    );
    _replace(updated);
    return updated;
  }

  Future<ChatMessage> _send(ChatMessage message) async {
    final saved = await repository.sendChatMessage(uid, batchId, message);
    if (_disposed) return saved;
    final existing = state.messages.any((item) => item.id == saved.id);
    if (!existing) {
      final messages = [...state.messages, saved]..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
      _emit(state.copyWith(messages: messages, initialized: true));
    }
    return saved;
  }

  void _replace(ChatMessage updated) {
    if (_disposed) return;
    _emit(
      state.copyWith(
        messages: [
          for (final message in state.messages)
            if (message.id == updated.id) updated else message,
        ],
      ),
    );
  }

  void _emit(ChatState next) {
    if (_disposed) return;
    state = next;
  }

  void _deleteTemp(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // The platform cache evicts the temporary file on its own.
    }
  }
}
