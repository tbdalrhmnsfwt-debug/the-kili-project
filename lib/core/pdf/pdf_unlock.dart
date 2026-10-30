/// Turns a password-protected PDF into a plain one for the native renderer.
///
/// `PdfRenderer` only accepts a password from Android 15 (API 35), so below
/// that a correct password could not unlock anything at all. Syncfusion can
/// decrypt on every version, into the session temp directory; the reader
/// deletes that copy when it closes and the startup sweep clears the rest.
library;

import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Writes an unlocked copy of [input] to [output].
///
/// Returns false for a wrong password; the copy is written only on success.
typedef PdfUnlocker = Future<bool> Function({
  required File input,
  required String password,
  required File output,
});

/// The real [PdfUnlocker]: Syncfusion decrypts in memory and saves the result.
///
/// A file that cannot be decrypted at all is reported as a wrong password —
/// from the reader's side those two are the same question ("can this password
/// open this file?"). Filesystem errors propagate, and the caller turns them
/// into a storage failure instead of blaming the password.
Future<bool> unlockPdfTo({
  required File input,
  required String password,
  required File output,
}) async {
  // Read outside the catch: a missing or unreadable file is a storage
  // problem, and reporting it as a wrong password would send the reader into
  // an endless re-prompt for a file no password can fix.
  final bytes = await input.readAsBytes();
  final sf.PdfDocument document;
  try {
    document = sf.PdfDocument(inputBytes: bytes, password: password);
  } on Object {
    return false;
  }
  try {
    // Saving a loaded document keeps its security dictionary, which would
    // leave the copy locked with the same password. Clearing both passwords
    // and the permissions makes the encryptor report "no encryption", so the
    // copy opens without a prompt and without permission flags.
    final security = document.security;
    security.userPassword = '';
    security.ownerPassword = '';
    security.permissions.clear();
    final unlocked = await document.save();
    await output.parent.create(recursive: true);
    await output.writeAsBytes(unlocked, flush: true);
  } finally {
    document.dispose();
  }
  return true;
}
