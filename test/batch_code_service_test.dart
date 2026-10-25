import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';

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
  group('normalisation', () {
    test('accepts Arabic-Indic digits', () {
      expect(BatchCodeService.normalize('٠١٢٣٤٥٦٧'), '01234567');
    });

    test('accepts Extended Arabic-Indic digits', () {
      expect(BatchCodeService.normalize('۰۱۲۳۴۵۶۷'), '01234567');
    });

    test('ignores spaces, dashes and bidi marks but keeps the digits', () {
      expect(BatchCodeService.normalize(' ٠١٢‏ ٣٤٥-٦٧ '), '01234567');
    });

    test('preserves a leading zero', () {
      expect(BatchCodeService.normalize('00012345'), '00012345');
    });

    test('rejects letters, short and long input', () {
      expect(BatchCodeService.normalize('12a45678'), isNull);
      expect(BatchCodeService.normalize('1234567'), isNull);
      expect(BatchCodeService.normalize('123456789'), isNull);
      expect(BatchCodeService.normalize(''), isNull);
    });

    test('digitsOnly maps every digit script and drops separators', () {
      expect(BatchCodeService.digitsOnly('٠١٢٣-٤٥٦٧'), '01234567');
      expect(BatchCodeService.digitsOnly('۰۱۲۳ ۴۵۶۷'), '01234567');
      expect(BatchCodeService.digitsOnly('12 34'), '1234');
      expect(BatchCodeService.digitsOnly('abc'), '');
    });

    test('format groups a complete code and leaves the rest alone', () {
      expect(BatchCodeService.format('00000001'), '0000 0001');
      expect(BatchCodeService.format('٠١٢٣٤٥٦٧'), '0123 4567');
      expect(BatchCodeService.format('123'), '123');
    });

    test('matches only complete, normalised codes', () {
      expect(BatchCodeService.matches('٠١٢٣٤٥٦٧', '01234567'), isTrue);
      expect(BatchCodeService.matches(' 0123-4567 ', '01234567'), isTrue);
      expect(BatchCodeService.matches('1234567', '01234567'), isFalse);
      expect(BatchCodeService.matches('01234568', '01234567'), isFalse);
      expect(BatchCodeService.matches('abcdefgh', '01234567'), isFalse);
    });
  });

  group('generation', () {
    test('always produces eight digits including leading zeros', () {
      final service = BatchCodeService(random: _SequenceRandom([42]));
      expect(service.generateUnique(taken: const {}), '00000042');
    });

    test('skips a taken code', () {
      final service = BatchCodeService(
        random: _SequenceRandom([12345, 12345, 54321]),
      );
      final first = service.generateUnique(taken: const {});
      expect(first, '00012345');
      final second = service.generateUnique(taken: {first});
      expect(second, '00054321');
      expect(second, isNot(first));
    });

    test('generateUniqueWhere uses the repository predicate', () {
      final service = BatchCodeService(random: _SequenceRandom([7, 8]));
      final code = service.generateUniqueWhere(
        isTaken: (candidate) =>
            BatchCodeService.codeHash(candidate) ==
            BatchCodeService.codeHash('00000007'),
      );
      expect(code, '00000008');
    });
  });

  group('hashing', () {
    test('is stable, normalised and 64 hex characters', () {
      final a = BatchCodeService.codeHash('01234567');
      final b = BatchCodeService.codeHash('٠١٢٣٤٥٦٧');
      expect(a, b);
      expect(a.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
    });

    test('refuses to hash an incomplete code', () {
      expect(
        () => BatchCodeService.codeHash('123'),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.invalidCode,
          ),
        ),
      );
    });
  });

  group('CodeAttemptGuard', () {
    final start = DateTime.utc(2026, 10, 25, 12);

    void fail(CodeAttemptGuard guard, int times, [DateTime? at]) {
      for (var i = 0; i < times; i++) {
        guard.recordFailure(at);
      }
    }

    test('allows five failures, then locks for the base cooldown', () {
      final guard = CodeAttemptGuard(clock: () => start);
      fail(guard, 4);
      expect(guard.canAttempt(), isTrue);
      guard.recordFailure();
      expect(guard.canAttempt(), isFalse);
      expect(guard.remaining(), const Duration(minutes: 1));
      expect(
        guard.canAttempt(start.add(const Duration(seconds: 59))),
        isFalse,
      );
      expect(
        guard.canAttempt(start.add(const Duration(seconds: 60))),
        isTrue,
      );
    });

    test('doubles the wait for each block and caps it', () {
      final guard = CodeAttemptGuard(clock: () => start);
      fail(guard, 5);
      expect(guard.remaining(), const Duration(minutes: 1));

      var at = start.add(const Duration(minutes: 1));
      fail(guard, 5, at);
      expect(guard.remaining(at), const Duration(minutes: 2));

      at = at.add(const Duration(minutes: 2));
      fail(guard, 5, at);
      expect(guard.remaining(at), const Duration(minutes: 4));

      at = at.add(const Duration(minutes: 4));
      fail(guard, 5, at);
      expect(guard.remaining(at), const Duration(minutes: 8));

      // Sixteen minutes would exceed the cap.
      at = at.add(const Duration(minutes: 8));
      fail(guard, 5, at);
      expect(guard.remaining(at), const Duration(minutes: 10));
    });

    test('forgets failures outside the window', () {
      final guard = CodeAttemptGuard(clock: () => start);
      fail(guard, 4);
      expect(guard.failures, 4);

      final later = start.add(const Duration(minutes: 11));
      expect(guard.canAttempt(later), isTrue);
      guard.recordFailure(later);
      expect(guard.failures, 1);
    });

    test('reset clears both the count and the lock', () {
      final guard = CodeAttemptGuard(clock: () => start);
      fail(guard, 5);
      expect(guard.canAttempt(), isFalse);
      guard.reset();
      expect(guard.canAttempt(), isTrue);
      expect(guard.failures, 0);
      expect(guard.blocks, 0);
      expect(guard.remaining(), Duration.zero);
    });

    test('round-trips only timestamps and counters', () {
      final guard = CodeAttemptGuard(clock: () => start);
      fail(guard, 5);
      final restored = CodeAttemptGuard.fromJson(
        guard.toJson(),
        clock: () => start,
      );
      expect(restored.canAttempt(), isFalse);
      expect(restored.remaining(), const Duration(minutes: 1));
      expect(restored.blocks, 1);
    });
  });
}
