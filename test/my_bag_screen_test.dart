import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_preview_provider.dart';
import 'package:zaker_ai/features/bag/my_bag_screen.dart';
import 'package:zaker_ai/providers/app_providers.dart';

BagFolderPreview _folder(String name, {int pdfs = 0}) => BagFolderPreview(
      id: name,
      name: name,
      colorValue: 0xFF2F5EA8,
      pocketCounts: [pdfs, 0, 0, 0],
    );

Widget _app(
  List<BagFolderPreview> folders, {
  double textScale = 1,
}) =>
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        bagFolderPreviewProvider.overrideWithValue(folders),
      ],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const MyBagScreen(),
      ),
    );

void main() {
  test('/bag is the deep link for the second tab', () {
    expect(ZakerRoutes.bag, '/bag');
  });

  testWidgets('the bag screen names itself and keeps the library one tap away',
      (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    // The AppBar title and the red hero both read «شنطتي».
    expect(find.text('شنطتي'), findsWidgets);
    expect(find.text('المكتبة الدراسية'), findsOneWidget);
    expect(find.byKey(const Key('my-bag-library-button')), findsOneWidget);
  });

  testWidgets('shows one chip with four pocket dots per folder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_folder('الرياضيات', pdfs: 2), _folder('العلوم')]),
    );
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(find.text('العلوم'), findsOneWidget);
    expect(find.byKey(const Key('bag-dot-الرياضيات-3')), findsOneWidget);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app([_folder('الرياضيات'), _folder('العلوم')], textScale: 2),
    );
    expect(tester.takeException(), isNull);
  });
}
