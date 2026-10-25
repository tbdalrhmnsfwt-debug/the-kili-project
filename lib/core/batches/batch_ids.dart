/// File-safe identifiers for batches and their records.
library;

import 'dart:math';

const String _alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
final Random _random = Random.secure();

/// A random token over an unambiguous lowercase alphabet.
///
/// Every alphabet character maps to exactly one byte value, so `nextInt(32)`
/// is uniform and no rejection sampling is needed.
String randomToken(int length) {
  assert(length > 0);
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
  }
  return buffer.toString();
}

/// A new batch directory name.
String newBatchId() => randomToken(20);

/// A prefixed id for a record inside a batch.
String newEntityId(String prefix) {
  assert(prefix.isNotEmpty);
  return '${prefix}_${randomToken(16)}';
}

/// An eight-digit invitation code.
///
/// Leading zeros are significant: the code is always exactly eight characters.
String newInviteCode() {
  return _random.nextInt(100000000).toString().padLeft(8, '0');
}
