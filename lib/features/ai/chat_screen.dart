/// The chat with the assistant "Fahim".
///
/// The shipped string that describes this screen reads:
/// `محادثة مع «فهيم» — اسأل أي حاجة في مناهجك وهو يشرحلك، والرد بيتكتب قدامك.`
/// ("Chat with Fahim — ask anything about your subjects and he explains it,
/// with the reply typing out live.")
///
/// The backend is pluggable: the on-device model (`llm_llamacpp`) when a
/// model has been installed, the remote API otherwise.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/ai.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The chat screen.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.subject, this.initialQuestion});

  /// Scopes the conversation to one subject, when known.
  final String? subject;

  /// A question to send as soon as the screen opens.
  final String? initialQuestion;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuestion?.trim();
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.text = initial;
        _send();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(
        ChatMessage(role: 'user', text: text, createdAt: DateTime.now()),
      );
      _controller.clear();
      _sending = true;
    });
    _scrollToEnd();

    final reply = await _ask(text);
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(role: 'assistant', text: reply, createdAt: DateTime.now()),
      );
      _sending = false;
    });
    _scrollToEnd();
  }

  /// Asks the assistant for a reply.
  ///
  /// Falls back to the canned local answer when neither the on-device model
  /// nor the remote API is reachable, so the screen is never a dead end.
  Future<String> _ask(String question) async {
    try {
      final service = ref.read(aiServiceProvider);
      final answer = await service.ask(question, subject: widget.subject);
      if (answer.trim().isNotEmpty) return answer;
    } catch (_) {
      // fall through to the canned reply
    }
    return 'مش لاقي إجابة دلوقتي — جرّب تسأل تاني أو افتح الدرس نفسه.';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = ref.watch(aiBackendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة مع «فهيم»'),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => setState(_messages.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Expanded(
              child: _ChatIntro(
                subject: widget.subject,
                backend: backend,
                onSuggestion: (s) {
                  _controller.text = s;
                  _send();
                },
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(ZakerSpacing.lg),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return const _TypingBubble();
                  }
                  return _Bubble(message: _messages[index]);
                },
              ),
            ),
          const Divider(height: 1),
          _Composer(controller: _controller, sending: _sending, onSend: _send),
          if (theme.textTheme.bodySmall != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ZakerSpacing.xs),
              child: Text(
                'الرد بيتكتب قدامك — الردود من المناهج بتاعتك.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The empty state, offering a few starter questions.
class _ChatIntro extends StatelessWidget {
  const _ChatIntro({
    required this.subject,
    required this.backend,
    required this.onSuggestion,
  });

  final String? subject;
  final AiBackend backend;
  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    'اشرحلي الدرس ده بطريقة سهلة',
    'اعمللي أسئلة على الفصل اللي فات',
    'ما هي أهم النقاط اللي لازم أحفظها؟',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        const SizedBox(height: ZakerSpacing.xl),
        Icon(
          Icons.smart_toy_rounded,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: ZakerSpacing.lg),
        Text(
          subject == null ? 'اسأل أي حاجة' : 'اسأل عن $subject',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        Text(
          'اسأل أي حاجة في مناهجك وهو يشرحلك، والرد بيتكتب قدامك.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        Center(
          child: StatChip(
            value: _backendLabel(backend),
            label: 'المحرك',
            icon: Icons.memory_rounded,
          ),
        ),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(title: 'جرّب تسأل'),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerRight,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => onSuggestion(s),
              child: Text(s),
            ),
          ),
      ],
    );
  }

  static String _backendLabel(AiBackend backend) => switch (backend) {
    AiBackend.onDevice => 'على الجهاز',
    AiBackend.cloud => 'السحابة',
    AiBackend.canned => 'جاهز',
  };
}

/// One chat bubble.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.md,
          vertical: ZakerSpacing.sm + 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.cardTheme.color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(ZakerRadius.md),
            topRight: const Radius.circular(ZakerRadius.md),
            bottomLeft: Radius.circular(isUser ? ZakerRadius.md : 4),
            bottomRight: Radius.circular(isUser ? 4 : ZakerRadius.md),
          ),
          border: isUser
              ? null
              : Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isUser ? Colors.white : theme.colorScheme.onSurface,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

/// The "typing…" placeholder.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.md,
          vertical: ZakerSpacing.md,
        ),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: ZakerSpacing.sm),
            Text('فهيم بيكتب…'),
          ],
        ),
      ),
    );
  }
}

/// The message composer.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'اكتب سؤالك…',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: ZakerSpacing.sm),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
