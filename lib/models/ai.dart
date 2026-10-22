/// AI feature models: the on-device assistant "Fahim", mind maps, summaries,
/// whiteboards and the AI study tools.
///
/// The shipped strings name the assistant and describe the pipeline:
///   * `محادثة مع «فهيم» — اسأل أي حاجة في مناهجك وهو يشرحلك، والرد بيتكتب قدامك.`
///   * `الفيديو والملخص الصوتي والمدرس والسبورة بيتكلموا بصوت على موبايلك.`
///   * `التطبيق بياخد محاضرتك — صوت أو صورة أو PDF — ويحولها لملخص وأسئلة وامتحانات وخرايط ذهنية.`
///   * `اختار شكل من ١٢: خريطة مفاهيم، جدول مقارنة، مخطط خطوات، عضمة السمكة، وكروت سوشيال وغيرهم.`
library;

import 'dart:convert';

/// Where a request is being served from.
enum AiBackend {
  /// The bundled llama.cpp model running on-device (`llm_llamacpp`).
  onDevice,

  /// The remote API at `students.moalemai.com`.
  cloud,

  /// A human-written answer shipped in the assets.
  canned,
}

/// A single message in a conversation with Fahim.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.createdAt,
    this.pending = false,
  });

  /// `user` or `assistant`.
  final String role;
  final String text;
  final DateTime? createdAt;

  /// True while the reply is still streaming in.
  final bool pending;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String? ?? 'user',
    text: json['text'] as String? ?? '',
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
  );
}

/// A conversation with the assistant.
class ChatThread {
  ChatThread({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    this.subject,
  }) : messages = messages ?? <ChatMessage>[];

  final String id;
  final String title;

  /// The transcript, oldest first.
  final List<ChatMessage> messages;

  /// The subject the thread is scoped to, when known.
  final String? subject;

  /// The last message exchanged, for list previews.
  String get preview => messages.isEmpty ? '' : messages.last.text;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (subject != null) 'subject': subject,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subject: json['subject'] as String?,
    messages: ((json['messages'] as List?) ?? const [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// The twelve visual styles the mind-map builder offers.
///
/// The shipped string: `اختار شكل من ١٢: خريطة مفاهيم، جدول مقارنة، مخطط
/// خطوات، عضمة السمكة، وكروت سوشيال وغيرهم.`
enum MapStyle {
  conceptMap('خريطة مفاهيم'),
  comparisonTable('جدول مقارنة'),
  stepDiagram('مخطط خطوات'),
  fishbone('عضمة السمكة'),
  socialCards('كروت سوشيال'),
  timeline('خط زمني'),
  tree('شجرة'),
  cycle('دورة'),
  pyramid('هرم'),
  matrix('مصفوفة'),
  flowchart('مخطط انسيابي'),
  mindmap('خريطة ذهنية');

  const MapStyle(this.label);
  final String label;
}

/// A node in a generated mind map.
class MapNode {
  const MapNode({
    required this.id,
    required this.label,
    this.children = const [],
    this.note = '',
  });

  final String id;
  final String label;
  final List<MapNode> children;
  final String note;

  factory MapNode.fromJson(Map<String, dynamic> json) => MapNode(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? json['t'] as String? ?? '',
    note: json['note'] as String? ?? '',
    children: ((json['children'] as List?) ?? const [])
        .map((e) => MapNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A generated mind map.
class MindMap {
  const MindMap({
    required this.id,
    required this.title,
    required this.style,
    required this.root,
    this.createdAt,
  });

  final String id;
  final String title;
  final MapStyle style;
  final MapNode root;
  final DateTime? createdAt;

  /// Counts every node in the tree, root included.
  int get nodeCount {
    int walk(MapNode node) =>
        1 + node.children.fold<int>(0, (s, c) => s + walk(c));
    return walk(root);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'style': style.name,
    'root': {
      'id': root.id,
      'label': root.label,
      if (root.note.isNotEmpty) 'note': root.note,
      'children': root.children
          .map(
            (c) => {
              'id': c.id,
              'label': c.label,
              if (c.note.isNotEmpty) 'note': c.note,
              'children': c.children
                  .map((g) => {'id': g.id, 'label': g.label})
                  .toList(),
            },
          )
          .toList(),
    },
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

/// A generated summary of a lecture or lesson.
class AiSummary {
  const AiSummary({
    required this.title,
    required this.body,
    this.sections = const [],
    this.audioPath,
    this.createdAt,
  });

  final String title;

  /// The summary text (markdown).
  final String body;

  /// Optional sub-sections, e.g. "تعريفات", "مقارنات", "أسئلة متوقعة".
  final List<String> sections;

  /// Path to the rendered audio summary, when one was produced.
  final String? audioPath;

  final DateTime? createdAt;
}

/// The status of a long-running AI job.
enum AiJobStatus { queued, running, succeeded, failed, cancelled }

/// A background AI job (summary, mind map, question generation, …).
///
/// The original app runs these in the `AiJobService` foreground service and
/// surfaces progress through the `ZToolsWidget` home-screen widget.
class AiJob {
  AiJob({
    required this.id,
    required this.kind,
    required this.status,
    this.title = '',
    this.progress = 0,
    this.outputPath,
    this.error,
    this.createdAt,
  });

  final String id;

  /// Job kind, e.g. `summary`, `mindmap`, `quiz`, `whiteboard`, `ocr`.
  final String kind;

  AiJobStatus status;
  final String title;

  /// Progress in the range 0..1.
  double progress;

  /// Where the finished artifact was written.
  String? outputPath;

  String? error;
  final DateTime? createdAt;

  bool get isFinished =>
      status == AiJobStatus.succeeded ||
      status == AiJobStatus.failed ||
      status == AiJobStatus.cancelled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'status': status.name,
    'title': title,
    'progress': progress,
    if (outputPath != null) 'outputPath': outputPath,
    if (error != null) 'error': error,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory AiJob.fromJson(Map<String, dynamic> json) => AiJob(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    status: AiJobStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => AiJobStatus.queued,
    ),
    title: json['title'] as String? ?? '',
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    outputPath: json['outputPath'] as String?,
    error: json['error'] as String?,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
  );
}

/// A saved AI output ("مخرجاتي" in the shipped strings).
class AiOutput {
  const AiOutput({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.path,
    this.preview = '',
  });

  final String id;

  /// Output kind: `summary`, `mindmap`, `quiz`, `sheet`, `pdf`, `whiteboard`.
  final String kind;

  final String title;
  final DateTime createdAt;

  /// Path to the produced file (PDF / PNG / audio).
  final String? path;

  /// A short text preview, when the output is textual.
  final String preview;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    if (path != null) 'path': path,
    if (preview.isNotEmpty) 'preview': preview,
  };

  factory AiOutput.fromJson(Map<String, dynamic> json) => AiOutput(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    title: json['title'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    path: json['path'] as String?,
    preview: json['preview'] as String? ?? '',
  );
}

/// Encodes a chat thread for persistence.
String encodeChatThread(ChatThread thread) => jsonEncode(thread.toJson());

/// Decodes a chat thread persisted by [encodeChatThread].
ChatThread decodeChatThread(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ChatThread.fromJson(json);
}
