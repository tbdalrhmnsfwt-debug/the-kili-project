import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/ai_service.dart';
import 'package:zaker_ai/core/api_client.dart';
import 'package:zaker_ai/core/asset_service.dart';
import 'package:zaker_ai/core/curriculum_search.dart';
import 'package:zaker_ai/models/ai.dart';

/// Answers every HTTP request with [body], or throws when it is null.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = body;
    if (reply == null) {
      throw StateError('offline');
    }
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _api(Map<String, dynamic>? reply) =>
    ApiClient(dio: Dio()..httpClientAdapter = _StubAdapter(reply));

/// The bundled books, with the index replaced by one fixed answer.
class _FakeKnowledge extends CurriculumSearch {
  _FakeKnowledge(this.reply) : super(AssetService());

  final String? reply;

  @override
  Future<String?> answer(String question, {String? subject}) async => reply;
}

void main() {
  group('AiService.askDetailed', () {
    test('reports the cloud when the backend answers', () async {
      final service = AiService(api: _api({'answer': '42'}));

      final answer = await service.askDetailed('كم يساوي 6×7؟');

      expect(answer.backend, AiBackend.cloud);
      expect(answer.text, '42');
    });

    test('reports a canned answer when the backend is unreachable', () async {
      final service = AiService(api: _api(null));

      final answer = await service.askDetailed('عايز ملخص');

      expect(answer.backend, AiBackend.canned);
      expect(answer.text, contains('ملخص سريع'));
    });

    test('a textbook answer is still not the cloud model', () async {
      final service = AiService(
        api: _api(null),
        knowledge: _FakeKnowledge('نص من الكتاب'),
      );

      final answer = await service.askDetailed('إيه تعريف الخلية؟');

      expect(answer.backend, AiBackend.canned);
      expect(answer.text, 'نص من الكتاب');
    });

    test('ask records both turns and returns the same text', () async {
      final service = AiService(api: _api({'answer': '42'}));

      final text = await service.ask('كم يساوي 6×7؟');

      expect(text, '42');
      expect(service.history.map((m) => m.role), ['user', 'assistant']);
      expect(service.history.last.text, '42');
    });
  });

  group('AiService.askGrounded', () {
    test('returns null instead of a canned answer when offline', () async {
      final service = AiService(api: _api(null));

      final answer = await service.askGrounded(
        question: 'اشرح الدرس',
        context: 'نص الصفحة',
      );

      expect(answer, isNull);
    });

    test('returns the trimmed answer when the backend answers', () async {
      final service = AiService(api: _api({'answer': '  شرح مختصر  '}));

      final answer = await service.askGrounded(
        question: 'اشرح الدرس',
        context: 'نص الصفحة',
      );

      expect(answer, 'شرح مختصر');
    });
  });
}
