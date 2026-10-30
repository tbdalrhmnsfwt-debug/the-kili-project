import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/shell_screen.dart';

Widget _host(
  Widget child, {
  ZakerThemeStyle style = ZakerThemeStyle.light,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: ZakerTheme.forStyle(style),
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: inner ?? const SizedBox.shrink(),
      ),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('bottom bar keeps five tabs and paints the selected one', (
    tester,
  ) async {
    await tester
        .pumpWidget(_host(ShellBottomNav(selected: 1, onSelect: (_) {})));
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('شخصي'), findsOneWidget);
    expect(find.text('الاختبار'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الدفعات'), findsOneWidget);
    expect(find.text('المكتبة الدراسية'), findsNothing);
    expect(find.byKey(const Key('nav-selected-dot')), findsOneWidget);

    final label = tester.widget<Text>(find.text('شخصي'));
    expect(label.style?.color, Colors.white);
  });

  testWidgets('sidebar shows the brand and the studio credit', (tester) async {
    await tester.pumpWidget(
      _host(ShellSidebar(selected: 0, onSelect: (_) {}, userName: 'طالب')),
    );
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.text(RafiqBrand.studio), findsOneWidget);
    expect(find.text('ذاكرلي'), findsNothing);
  });

  testWidgets('no overflow at 320 dp and 2.0x text in any appearance', (
    tester,
  ) async {
    // The logical surface, not just a MediaQuery value: layout constraints
    // come from the view, so this is what actually forces 320 dp.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final style in ZakerThemeStyle.values) {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              Expanded(
                child: ShellSidebar(
                  selected: 3,
                  onSelect: (_) {},
                  userName: 'طالب',
                ),
              ),
            ],
          ),
          style: style,
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull, reason: '${style.id} sidebar');

      await tester.pumpWidget(
        _host(
          ShellBottomNav(selected: 3, onSelect: (_) {}),
          style: style,
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull, reason: '${style.id} bottom bar');
    }
  });
}
