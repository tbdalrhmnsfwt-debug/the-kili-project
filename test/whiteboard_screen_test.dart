import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/ai_service.dart';
import 'package:zaker_ai/core/api_client.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/whiteboard/whiteboard_screen.dart';
import 'package:zaker_ai/providers/app_providers.dart';

/// Answers every request with [body], or throws when it is null.
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

Widget _screen({Map<String, dynamic>? reply}) => ProviderScope(
      overrides: [
        aiServiceProvider.overrideWithValue(
          AiService(
              api: ApiClient(
                  dio: Dio()..httpClientAdapter = _StubAdapter(reply))),
        ),
      ],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        home: const WhiteboardScreen(lessonTitle: 'الخلية'),
      ),
    );

/// A tall surface, so the result at the end of the list is built.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('an offline render shows a notice, not app guidance', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_screen());
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('الخدمة مش متاحة دلوقتي'), findsOneWidget);
    // The canned reply tells the student to open another screen; presenting
    // it as the script would be a lie with a copy button beside it.
    expect(find.byTooltip('انسخ الشرح'), findsNothing);
  });

  testWidgets('a cloud answer becomes the script', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _screen(reply: {'answer': 'الخلية وحدة بناء الكائن الحي.'}),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('الخلية وحدة بناء الكائن الحي.'), findsOneWidget);
    expect(find.byTooltip('انسخ الشرح'), findsOneWidget);
    expect(find.text('الخدمة مش متاحة دلوقتي'), findsNothing);
  });
}
