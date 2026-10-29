import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/localization.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/my_bag_screen.dart';
import 'package:zaker_ai/features/home/shell_screen.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';

import 'support/my_bag_fixtures.dart';

void main() {
  late Directory root;
  late MyBagStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zaker_bag_ui_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  MyBagFolder folder(String gradeId, String name) => MyBagFolder.subject(
        gradeId: gradeId,
        subjectKey: name,
        name: name,
        colorValue: 0xFF2F5EA8,
        createdAt: DateTime.utc(2026, 10, 1),
      );

  const mathSeed = MyBagSubjectSeed(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
  );

  Widget app({
    List<MyBagSubjectSeed> seeds = const [],
    double textScale = 1,
  }) =>
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          myBagStoreProvider.overrideWithValue(store),
          bagSeedSubjectsProvider.overrideWithValue(seeds),
          bagSubjectProgressProvider.overrideWithValue(const {}),
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

  test('/bag is the deep link for the second tab', () {
    expect(ZakerRoutes.bag, '/bag');
  });

  testWidgets('the bag screen names itself and keeps the library one tap away',
      (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('شنطتي'), findsWidgets);
    expect(find.byKey(const Key('my-bag-library-button')), findsOneWidget);
    expect(find.byKey(const Key('my-bag-empty')), findsOneWidget);
  });

  testWidgets('the selected grade seeds its subject folders', (tester) async {
    await tester.pumpWidget(app(seeds: const [mathSeed]));
    await tester.pumpAndSettle();
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(
      find.byKey(const Key('bag-folder-card-subject:sec1:الرياضيات')),
      findsOneWidget,
    );
  });

  testWidgets('the current grade is the default and «كل الصفوف» shows the rest',
      (
    tester,
  ) async {
    await store.saveIndex(
      MyBagIndex(
        folders: [
          folder('sec1', 'الرياضيات'),
          folder('prep1', 'العلوم'),
        ],
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(find.text('العلوم'), findsNothing);

    await tester.tap(find.byKey(const Key('my-bag-grade-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-bag-filter-all')).last);
    await tester.pumpAndSettle();
    expect(find.text('العلوم'), findsOneWidget);
  });

  testWidgets('search narrows the grid', (tester) async {
    await store.saveIndex(
      MyBagIndex(
        folders: [
          folder('sec1', 'الرياضيات'),
          folder('sec1', 'العلوم'),
        ],
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my-bag-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('my-bag-search-field')),
      'رياض',
    );
    await tester.pumpAndSettle();
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(find.text('العلوم'), findsNothing);
  });

  testWidgets('«أضف مادة» creates a custom folder', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my-bag-add-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('my-bag-custom-name')),
      'أوراقي',
    );
    await tester.tap(find.text('أضف'));
    await tester.pumpAndSettle();

    expect(find.text('أوراقي'), findsOneWidget);
    expect(store.loadIndex().folders.single.custom, isTrue);
  });

  testWidgets('deleting a seeded folder warns and stays deleted', (
    tester,
  ) async {
    await tester.pumpWidget(app(seeds: const [mathSeed]));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('bag-folder-menu-subject:sec1:الرياضيات')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المجلد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('التسجيلات وصور البورد'), findsOneWidget);

    await tester.tap(find.text('احذف'));
    await tester.pumpAndSettle();
    expect(find.text('الرياضيات'), findsNothing);
    expect(
      store.loadHiddenSubjectIds(),
      contains('subject:sec1:الرياضيات'),
    );
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await store.saveIndex(
      MyBagIndex(
        folders: [
          folder('sec1', 'الرياضيات'),
          folder('sec1', 'العلوم'),
        ],
      ),
    );
    await tester.pumpWidget(app(textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pushed bag screen offers a back button that pops', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          myBagStoreProvider.overrideWithValue(store),
          bagSeedSubjectsProvider.overrideWithValue(const []),
          bagSubjectProgressProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: ZakerTheme.light(),
          home: const Scaffold(body: Text('root')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => ShellMenuScope(
          openDrawer: () {},
          enabled: true,
          child: const MyBagScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('the bag controls follow the English table', (tester) async {
    await store.saveIndex(
      MyBagIndex(folders: [folder('sec1', 'الرياضيات')]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          myBagStoreProvider.overrideWithValue(store),
          bagSeedSubjectsProvider.overrideWithValue(const []),
          bagSubjectProgressProvider.overrideWithValue(const {}),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [_EnglishDelegate()],
          home: const MyBagScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search my bag'), findsOneWidget);
    expect(find.byTooltip('Current grade'), findsOneWidget);
    expect(find.byTooltip('Folder options'), findsOneWidget);

    await tester.tap(find.byKey(const Key('my-bag-search')));
    await tester.pumpAndSettle();
    expect(find.text('Search my bag'), findsWidgets);

    // The seeded folder card pushes the add tile below the fold at 800x600.
    await tester.ensureVisible(find.byKey(const Key('my-bag-add-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-bag-add-custom')));
    await tester.pumpAndSettle();
    expect(find.text('Subject name'), findsOneWidget);
  });

  testWidgets('the hero copy stays readable on the red banner', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // «شنطتي» is also the app-bar title, so the copy is read inside the hero.
    final hero = find.byKey(const Key('my-bag-hero'));
    final title = tester.widget<Text>(
      find.descendant(of: hero, matching: find.text('شنطتي')),
    );
    final subtitle = tester.widget<Text>(
      find.descendant(of: hero, matching: find.text('كل موادك في شنطة واحدة')),
    );
    final decoration =
        tester.widget<Container>(hero).decoration! as BoxDecoration;
    final stops = (decoration.gradient! as LinearGradient).colors;
    for (final text in <(String, Text)>[
      ('title', title),
      ('subtitle', subtitle),
    ]) {
      for (final stop in stops) {
        final painted = Color.alphaBlend(text.$2.style!.color!, stop);
        expect(
          contrastRatio(painted, stop),
          greaterThanOrEqualTo(4.5),
          reason: '${text.$1} on $stop',
        );
      }
    }
  });
}

/// Installs the English table the bag's controls look up.
class _EnglishDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _EnglishDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(
        const Locale('en'),
        const {
          'بحث في شنطتي': 'Search my bag',
          'الصف الحالي': 'Current grade',
          'خيارات المجلد': 'Folder options',
          'اسم المادة': 'Subject name',
        },
      );

  @override
  bool shouldReload(_EnglishDelegate old) => false;
}
