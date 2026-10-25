import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_join_service.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/join_batch_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/providers/batch_providers.dart';
import 'package:zaker_ai/widgets/tr_text.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _SequenceRandom implements Random {
  _SequenceRandom(this.values);

  final List<int> values;
  int _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    final value = values[_index % values.length];
    _index++;
    return value % max;
  }
}

void main() {
  const uid = 'guest-0123456789';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  late Directory root;
  late BatchFileStore files;
  late _MemoryStore store;
  late DateTime now;

  LocalBatchRepository repository() => LocalBatchRepository(
        files: files,
        store: store,
        codes: BatchCodeService(
          random: _SequenceRandom([1, 2, 3, 4, 5, 6, 7, 8]),
        ),
        clock: () => fixed,
      );

  BatchJoinService service() => BatchJoinService(
        repository: repository(),
        store: store,
        clock: () => now,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_join_');
    files = BatchFileStore(root: root);
    store = _MemoryStore();
    now = fixed;
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('resolving a code', () {
    test('rejects a malformed code without spending an attempt', () async {
      final result = await service().resolve(uid: uid, input: '1234');

      expect(result.state, JoinCodeState.invalidFormat);
      expect(store.values, isEmpty);
    });

    test('reports a storage error when there is no workspace', () async {
      final result = await service().resolve(uid: '', input: '00000001');

      expect(result.state, JoinCodeState.storageError);
    });

    test('records misses, then locks after five', () async {
      final join = service();
      for (var i = 0; i < 5; i++) {
        final result = await join.resolve(uid: uid, input: '00000009');
        expect(result.state, JoinCodeState.notFound);
      }

      final locked = await join.resolve(uid: uid, input: '00000009');
      expect(locked.state, JoinCodeState.cooldown);
      expect(locked.remaining, const Duration(minutes: 1));

      // A new service over the same store keeps the lock.
      final restarted = service().resolve(uid: uid, input: '00000009');
      expect((await restarted).state, JoinCodeState.cooldown);

      // The stored state holds timestamps and counters, never the guess.
      final raw = store.values['batches.codefails.v1.$uid']!;
      expect(raw, isNot(contains('00000009')));
    });

    test('allows attempts again once the cooldown ends', () async {
      final join = service();
      for (var i = 0; i < 5; i++) {
        await join.resolve(uid: uid, input: '00000009');
      }
      now = now.add(const Duration(seconds: 61));

      final result = await join.resolve(uid: uid, input: '00000009');
      expect(result.state, JoinCodeState.notFound);
    });

    test('reports the account that already owns the batch', () async {
      final localRepository = repository();
      final batch = await localRepository.createBatch(
        uid: uid,
        displayName: 'طالب',
        name: 'دفعة أولى',
        subjects: const ['رياضيات', 'فيزياء'],
      );

      final result = await service().resolve(
        uid: uid,
        input: BatchCodeService.format(batch.codeState.code),
      );

      expect(result.state, JoinCodeState.alreadyMember);
      expect(result.isSuccess, isTrue);
      expect(result.batch!.id, batch.id);
      expect(result.ownerName, 'طالب');
      expect(result.subjectCount, 2);

      // A successful resolution clears the failure window.
      final guard = store.values['batches.codefails.v1.$uid'];
      expect(guard, isNotNull);
      expect(guard, isNot(contains('lockedUntil')));
    });

    test('previews a code the account is not a member of', () async {
      final localRepository = repository();
      final batch = await localRepository.createBatch(
        uid: uid,
        displayName: 'طالب',
        name: 'دفعة أولى',
        subjects: const [],
      );
      final storeDoc = BatchStore(
        directory: files.batchDir(uid, batch.id),
      );
      final load = await storeDoc.batch.load();
      await storeDoc.batch.save(
        load.value!.copyWith(
          members: [
            Membership(
              batchId: batch.id,
              uid: 'someone-else',
              displayName: 'حد تاني',
              role: BatchRole.member,
              joinedAt: fixed,
            ),
          ],
        ),
      );

      final result = await service().resolve(
        uid: uid,
        input: batch.codeState.code,
      );

      expect(result.state, JoinCodeState.pendingUnsupported);
      expect(result.isSuccess, isFalse);
      expect(result.batch!.name, 'دفعة أولى');
      expect(result.subjectCount, 0);
    });

    test('reports a revoked code', () async {
      final localRepository = repository();
      final batch = await localRepository.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة أولى',
        subjects: const [],
      );
      await localRepository.revokeCode(uid, batch.id);

      final result = await service().resolve(
        uid: uid,
        input: batch.codeState.code,
      );

      expect(result.state, JoinCodeState.revoked);
    });
  });

  group('join screen', () {
    Widget app(JoinCodeResolver resolver) {
      return ProviderScope(
        overrides: [
          batchJoinResolverProvider.overrideWith((ref) => resolver),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const JoinBatchScreen(),
        ),
      );
    }

    testWidgets('groups Arabic digits and sends the normalised code', (
      tester,
    ) async {
      String? received;
      await tester.pumpWidget(
        app((input) async {
          received = input;
          return const JoinCodeResolution(JoinCodeState.invalidFormat);
        }),
      );

      await tester.enterText(find.byType(TextField), '٠١٢٣٤٥٦٧');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '0123 4567',
      );

      await tester.tap(find.text('تحقق من الكود'));
      await tester.pumpAndSettle();

      expect(received, '0123 4567');
      expect(find.text('الكود مش مكتمل'), findsOneWidget);
    });

    testWidgets('shows the honest local-only reason for an unknown code', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          (_) async => const JoinCodeResolution(JoinCodeState.notFound),
        ),
      );

      await tester.enterText(find.byType(TextField), '00000009');
      await tester.tap(find.text('تحقق من الكود'));
      await tester.pumpAndSettle();

      expect(find.text('مفيش دفعة بالكود ده'), findsOneWidget);
      expect(find.textContaining('محتاج سيرفر'), findsOneWidget);
    });

    testWidgets('previews a matching batch for an existing member', (
      tester,
    ) async {
      final createdAt = DateTime.utc(2026, 10, 25, 8);
      final batch = Batch(
        id: 'batch-1',
        name: 'دفعة أولى',
        ownerUid: uid,
        createdAt: createdAt,
        settings: const BatchSettings(),
        subjects: const [],
        codeState: InviteCodeState(code: '00000001', createdAt: createdAt),
      );
      await tester.pumpWidget(
        app(
          (_) async => JoinCodeResolution(
            JoinCodeState.alreadyMember,
            batch: batch,
            ownerName: 'طالب',
            subjectCount: 3,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '00000001');
      await tester.tap(find.text('تحقق من الكود'));
      await tester.pumpAndSettle();

      expect(find.text('أنت عضو بالفعل'), findsWidgets);
      expect(find.text('دفعة أولى'), findsOneWidget);
      expect(find.text('طالب'), findsOneWidget);
      expect(find.text('3 مواد'), findsOneWidget);
      expect(find.byType(TrText), findsWidgets);
    });
  });
}
