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

    test('allows four failures, then locks for the base cooldown', () {
      final guard = CodeAttemptGuard(clock: () => start);
      for (var i = 0; i < 4; i++) {
        guard.recordFailure();
        expect(guard.canAttempt(), isTrue);
      }
      guard.recordFailure();
      expect(guard.canAttempt(), isFalse);
      expect(guard.remaining(), const Duration(seconds: 30));
      expect(guard.canAttempt(start.add(const Duration(seconds: 30))), isTrue);
    });

    test('doubles the wait for a second block and caps it', () {
      final guard = CodeAttemptGuard(
        maxCooldown: const Duration(minutes: 1),
        clock: () => start,
      );
      for (var i = 0; i < 5; i++) {
        guard.recordFailure();
      }
      expect(guard.remaining(), const Duration(seconds: 30));
      for (var i = 0; i < 5; i++) {
        guard.recordFailure();
      }
      expect(guard.remaining(), const Duration(minutes: 1));
      for (var i = 0; i < 5; i++) {
        guard.recordFailure();
      }
      expect(guard.remaining(), const Duration(minutes: 1));
    });

    test('reset clears both the count and the lock', () {
      final guard = CodeAttemptGuard(clock: () => start);
      for (var i = 0; i < 5; i++) {
        guard.recordFailure();
      }
      expect(guard.canAttempt(), isFalse);
      guard.reset();
      expect(guard.canAttempt(), isTrue);
      expect(guard.failures, 0);
      expect(guard.remaining(), Duration.zero);
    });
  });
}
