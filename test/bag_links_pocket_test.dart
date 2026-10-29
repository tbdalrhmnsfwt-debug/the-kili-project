import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/localization.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_pocket_screen.dart';
import 'package:zaker_ai/features/bag/pockets/links_pocket_body.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';

import 'support/my_bag_fixtures.dart';

void main() {
  late Directory root;
  late MyBagStore store;
  late List<Uri> opened;
  const folderId = 'subject:sec1:الرياضيات';
  final folder = MyBagFolder.subject(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
    createdAt: DateTime.utc(2026, 10, 1),
  );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_bag_links_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    opened = [];
    await store.saveIndex(MyBagIndex().upsert(folder));
  });

  tearDown(() => root.deleteSync(recursive: true));

  Widget app({Locale? locale}) => ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          myBagStoreProvider.overrideWithValue(store),
          bagSeedSubjectsProvider.overrideWithValue(const []),
          bagSubjectProgressProvider.overrideWithValue(const {}),
          bagLinkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates:
              locale == null ? null : const [_EnglishDelegate()],
          home: const BagPocketScreen(
            folderId: folderId,
            kind: BagPocketKind.links,
          ),
        ),
      );

  // Link writes reach the disk through real file I/O, which pumpAndSettle does
  // not wait for: poll until [done] holds, then settle the frames it queued.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100; i++) {
      if (done()) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> addLink(WidgetTester tester, String title, String url) async {
    await tester.tap(find.byKey(const Key('bag-link-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bag-link-title')), title);
    await tester.enterText(find.byKey(const Key('bag-link-url')), url);
    await tester.tap(find.byKey(const Key('bag-link-save')));
    await tester.pump();
  }

  testWidgets('a hostile link is refused with an explanation', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await addLink(tester, 'خطر', 'javascript:alert(1)');
    await waitFor(
      tester,
      () => find.byKey(const Key('bag-link-error')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('bag-link-error')), findsOneWidget);
    expect(store.loadMedia(folderId).links, isEmpty);
  });

  testWidgets('the refusal is written in the active language', (tester) async {
    await tester.pumpWidget(app(locale: const Locale('en')));
    await tester.pumpAndSettle();

    await addLink(tester, 'خطر', 'javascript:alert(1)');
    await waitFor(
      tester,
      () => find.byKey(const Key('bag-link-error')).evaluate().isNotEmpty,
    );

    expect(
      find.text('The link must start with http or https.'),
      findsOneWidget,
    );
    expect(find.text('الرابط لازم يبدأ بـ http أو https.'), findsNothing);
  });

  testWidgets('a valid link opens in the external app', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await addLink(tester, 'درس', 'https://example.com/lesson');
    await waitFor(tester, () => store.loadMedia(folderId).links.isNotEmpty);
    expect(store.loadMedia(folderId).links, hasLength(1));

    final link = store.loadMedia(folderId).links.single;
    expect(find.text('درس'), findsOneWidget);
    expect(find.textContaining('example.com'), findsWidgets);

    await tester.tap(find.byKey(Key('bag-link-${link.id}')));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://example.com/lesson')]);
  });

  testWidgets('long-press edits and deletes', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addLink(tester, 'درس', 'https://example.com');
    await waitFor(tester, () => store.loadMedia(folderId).links.isNotEmpty);
    final link = store.loadMedia(folderId).links.single;

    await tester.longPress(find.byKey(Key('bag-link-${link.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bag-link-title')), 'درس ٢');
    await tester.tap(find.byKey(const Key('bag-link-save')));
    await waitFor(tester, () => find.text('درس ٢').evaluate().isNotEmpty);
    expect(find.text('درس ٢'), findsOneWidget);

    await tester.tap(find.byKey(Key('bag-link-menu-${link.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احذف'));
    await waitFor(tester, () => store.loadMedia(folderId).links.isEmpty);
    expect(store.loadMedia(folderId).links, isEmpty);
  });
}

/// Installs the English table the link dialog's error line looks up.
class _EnglishDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _EnglishDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(
        const Locale('en'),
        const {
          'الرابط لازم يبدأ بـ http أو https.':
              'The link must start with http or https.',
        },
      );

  @override
  bool shouldReload(_EnglishDelegate old) => false;
}
