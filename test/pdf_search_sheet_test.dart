import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/core/pdf/pdf_text_map.dart';
import '../lib/core/theme.dart';
import '../lib/features/pdf/widgets/pdf_search_sheet.dart';

class FakeTextMap extends PdfTextMap {
  FakeTextMap({this.matches = const [], this.hasText = true})
    : super.fromBytes(Uint8List(0), pageCount: 3);

  final List<PdfTextMatch> matches;
  final bool hasText;
  int searches = 0;

  @override
  Future<bool> hasAnyText() async => hasText;

  @override
  Future<List<PdfTextMatch>> search(String query) async {
    searches += 1;
    return matches;
  }
}

PdfTextMatch _match(int page) {
  return PdfTextMatch(
    pageIndex: page,
    bounds: const NormalizedRect(0.1, 0.2, 0.3, 0.05),
    snippet: 'نتيجة في صفحة ${page + 1}',
  );
}

Future<void> _pumpSheet(WidgetTester tester, PdfSearchSheet sheet) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ZakerTheme.light(),
      home: Scaffold(body: sheet),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('three matches list three rows and the second jumps to page 1', (
    tester,
  ) async {
    PdfTextMatch? jumped;
    final map = FakeTextMap(matches: [_match(0), _match(1), _match(2)]);
    await _pumpSheet(
      tester,
      PdfSearchSheet(textMap: map, onJump: (match) => jumped = match),
    );

    await tester.enterText(find.byType(TextField), 'كيمياء');
    await tester.tap(find.text('بحث'));
    await tester.pump();
    await tester.pump();

    expect(map.searches, 1);
    expect(find.byType(ListTile), findsNWidgets(3));

    await tester.tap(find.byType(ListTile).at(1));

    expect(jumped?.pageIndex, 1);
  });

  testWidgets('a document without text says so', (tester) async {
    final map = FakeTextMap(hasText: false);
    await _pumpSheet(tester, PdfSearchSheet(textMap: map, onJump: (_) {}));

    expect(find.text('الملف ده صور — مفيش نص نبحث فيه'), findsOneWidget);
  });

  testWidgets('a query with no hits says so', (tester) async {
    final map = FakeTextMap();
    await _pumpSheet(tester, PdfSearchSheet(textMap: map, onJump: (_) {}));

    await tester.enterText(find.byType(TextField), 'فيزياء');
    await tester.tap(find.text('بحث'));
    await tester.pump();
    await tester.pump();

    expect(find.text('مفيش نتايج حوالين «فيزياء»'), findsOneWidget);
  });
}
