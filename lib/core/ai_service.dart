/// The AI service: the single place that answers questions and produces
/// study artifacts.
///
/// Backends, in priority order:
///   1. The on-device model (`llm_llamacpp` / llama.cpp GGUF) when a model
///      has been downloaded to the app's private storage.
///   2. The remote API at `students.moalemai.com`.
///   3. A canned local answer, so the UI always has something to show.
///
/// The original app runs long jobs (summary, mind map, question generation)
/// inside the `AiJobService` foreground service; [AiService] mirrors that
/// with a job list the home-screen widget can poll.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai.dart';
import 'api_client.dart';
import 'curriculum_search.dart';

/// An answer, with the backend that actually produced it.
///
/// A caller that shows the text to the user needs this: the canned reply is
/// app guidance, not a model answer, and must not be presented as one.
class AiAnswer {
  const AiAnswer({required this.text, required this.backend});

  final String text;
  final AiBackend backend;
}

/// The AI service.
class AiService {
  AiService({ApiClient? api, CurriculumSearch? knowledge})
    : _api = api ?? ApiClient(),
      _knowledge = knowledge;

  final ApiClient _api;

  /// Offline retrieval over the bundled textbooks, used when the remote model
  /// cannot answer.
  final CurriculumSearch? _knowledge;

  /// The chat history for the current session.
  final List<ChatMessage> history = [];

  /// The jobs currently known to the service.
  final List<AiJob> jobs = [];

  /// Whether an on-device model has been installed.
  bool onDeviceModelReady = false;

  /// Whether the last remote request was answered by the backend.
  bool _remoteAnswered = false;

  /// The backend that will serve the next request.
  AiBackend get backend {
    if (onDeviceModelReady) return AiBackend.onDevice;
    if (_remoteAnswered) return AiBackend.cloud;
    return AiBackend.canned;
  }

  /// Asks a question and returns the answer text.
  Future<String> ask(String question, {String? subject}) async =>
      (await askDetailed(question, subject: subject)).text;

  /// Asks a question and reports which backend answered it.
  Future<AiAnswer> askDetailed(String question, {String? subject}) async {
    history.add(
      ChatMessage(role: 'user', text: question, createdAt: DateTime.now()),
    );

    final (text, backend) = await _askRemote(question, subject: subject);

    history.add(
      ChatMessage(role: 'assistant', text: text, createdAt: DateTime.now()),
    );
    return AiAnswer(text: text, backend: backend);
  }

  Future<(String, AiBackend)> _askRemote(
    String question, {
    String? subject,
  }) async {
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/ai/ask',
        data: {
          'question': question,
          if (subject != null) 'subject': subject,
          'history': history
              .take(12)
              .map((m) => {'role': m.role, 'text': m.text})
              .toList(),
        },
      );
      final answer = res.data?['answer'] as String?;
      if (answer != null && answer.trim().isNotEmpty) {
        _remoteAnswered = true;
        return (answer, AiBackend.cloud);
      }
    } catch (_) {
      // fall through to the offline sources
    }

    // The cloud model is unreachable: answer from the textbooks on the device
    // when they contain something relevant, before giving up.
    final local = await _knowledge?.answer(question, subject: subject);
    if (local != null && local.trim().isNotEmpty) {
      return (local, AiBackend.canned);
    }
    return (_cannedAnswer(question), AiBackend.canned);
  }

  /// Asks the cloud model to work only from [context].
  ///
  /// Unlike [ask], this returns `null` when the backend is unreachable or
  /// declines: a grounded explanation must never silently fall back to a
  /// canned answer that is not about the student's book.
  Future<String?> askGrounded({
    required String question,
    required String context,
    String? subject,
    int? pageStart,
    int? pageEnd,
  }) async {
    try {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/ai/ask',
        data: {
          'question': question,
          'subject': subject,
          'context': context,
          if (pageStart != null) 'page_start': pageStart,
          if (pageEnd != null) 'page_end': pageEnd,
          'require_citations': true,
          'history': const <Map<String, String>>[],
        },
      );
      final answer = res.data?['answer'] as String?;
      if (answer == null || answer.trim().isEmpty) return null;
      _remoteAnswered = true;
      return answer.trim();
    } catch (e) {
      debugPrint('AI grounded request failed: $e');
      return null;
    }
  }

  /// The offline fallback reply.
  ///
  /// It deliberately echoes the app's own tone: short, encouraging, and
  /// pointing at the concrete next action.
  String _cannedAnswer(String question) {
    final q = question.trim();
    if (q.contains('امتحان') || q.contains('اختبار')) {
      return 'أسهل طريقة: افتح «الاختبار» واختار امتحان الدرس ده — التصحيح بيظهر على طول، والمقالي بيتقيّم بدرجة وملاحظة.';
    }
    if (q.contains('احفظ') || q.contains('حفظ') || q.contains('تسميع')) {
      return 'للحفظ السريع ابدأ بالتعاريف والمصطلحات والتواريخ. افتح «الاسترجاع النشط» عشان الكروت ترجعلك في الوقت المناسب.';
    }
    if (q.contains('خريطة') || q.contains('ارسم')) {
      return 'أقدر أعملك خريطة ذهنية من الدرس — اختار «الخريطة الذهنية» من الأدوات، أو الصق نص الدرس هنا.';
    }
    if (q.contains('ملخص') || q.contains('لخص')) {
      return 'اعمل «ملخص سريع» من الدرس وهاخصّصه لك في نقاط مع أمثلة.';
    }
    return 'مش لاقي إجابة دلوقتي — جرّب تسأل تاني أو افتح الدرس نفسه.';
  }

  /// Generates a summary for a body of text.
  Future<AiSummary> summarize({
    required String title,
    required String text,
    String? subject,
  }) async {
    final body = await _guard(() async {
      final res = await _api.raw.post<Map<String, dynamic>>(
        '/ai/summarize',
        data: {
          'title': title,
          'text': text,
          if (subject != null) 'subject': subject,
        },
      );
      return res.data?['summary'] as String?;
    }, fallback: () => null);

    return AiSummary(
      title: title,
      body: body ?? _localSummary(text),
      createdAt: DateTime.now(),
    );
  }

  /// A purely local extractive summary, used when the API is unreachable.
  ///
  /// It picks the most sentence-like lines and keeps them in order.
  String _localSummary(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]'))
        .map((l) => l.trim())
        .where((l) => l.length > 24)
        .toList();
    if (lines.isEmpty) return text.trim();
    final picked = lines.take(8).toList();
    return picked.join('\n');
  }

  /// Generates a mind map for a body of text.
  Future<MindMap> mindMap({
    required String title,
    required String text,
    MapStyle style = MapStyle.conceptMap,
  }) async {
    final res = await _guard(() async {
      final r = await _api.raw.post<Map<String, dynamic>>(
        '/ai/mindmap',
        data: {'title': title, 'text': text, 'style': style.name},
      );
      return r.data;
    }, fallback: () => null);

    if (res != null) {
      return MindMap(
        id: 'mm-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        style: style,
        root: MapNode.fromJson(
          (res['root'] as Map?)?.cast<String, dynamic>() ??
              {'id': 'root', 'label': title},
        ),
        createdAt: DateTime.now(),
      );
    }

    return MindMap(
      id: 'mm-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      style: style,
      root: _localMindMap(title, text),
      createdAt: DateTime.now(),
    );
  }

  /// A local mind map: the title as root, and the first lines as branches.
  MapNode _localMindMap(String title, String text) {
    final branches = text
        .split(RegExp(r'[\n\r]'))
        .map((l) => l.trim())
        .where((l) => l.length > 16)
        .take(6)
        .toList();
    return MapNode(
      id: 'root',
      label: title,
      children: [
        for (var i = 0; i < branches.length; i++)
          MapNode(id: 'n$i', label: branches[i]),
      ],
    );
  }

  /// Enqueues a background job and reports progress through [onProgress].
  Future<AiJob> runJob({
    required String kind,
    required String title,
    required Future<void> Function(void Function(double) onProgress) work,
  }) async {
    final id = '$kind-${DateTime.now().millisecondsSinceEpoch}';
    final job = AiJob(
      id: id,
      kind: kind,
      status: AiJobStatus.running,
      title: title,
      createdAt: DateTime.now(),
    );
    jobs.add(job);

    try {
      await work((p) {
        job.progress = p.clamp(0.0, 1.0);
      });
      job.status = AiJobStatus.succeeded;
      job.progress = 1;
    } catch (e) {
      job.status = AiJobStatus.failed;
      job.error = e.toString();
    }
    return job;
  }

  /// Runs [action], returning [fallback] if it throws.
  Future<T> _guard<T>(
    Future<T> Function() action, {
    required T Function() fallback,
  }) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('AI service request failed: $e');
      return fallback();
    }
  }
}
