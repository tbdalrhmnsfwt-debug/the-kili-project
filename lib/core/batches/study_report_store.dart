/// Keeps a user-written problem report about generated study material on the
/// device.
///
/// Sending it to a developer needs a server, which this build does not have.
/// The store writes only the user's own message, the ids needed to find the
/// PDF and a timestamp — never chat text, answers, or a file path.
library;

import 'dart:convert';

import 'batch_failure.dart';
import 'batch_file_store.dart';
import 'batch_ids.dart';

class StudyReportStore {
  StudyReportStore({required this.files, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final BatchFileStore files;
  final DateTime Function() _clock;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static const int maxMessageChars = 1000;

  Future<String> save({
    required String uid,
    required String batchId,
    required String resourceId,
    required String message,
  }) async {
    if (uid.isEmpty) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    if (!_idPattern.hasMatch(resourceId) || !_idPattern.hasMatch(batchId)) {
      throw const BatchFailure(BatchFailureCode.validationFailed);
    }
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'message',
      );
    }
    final text = trimmed.length > maxMessageChars
        ? trimmed.substring(0, maxMessageChars)
        : trimmed;
    final stamp = _clock().toUtc();
    final relativePath = 'reports/study-'
        '${stamp.millisecondsSinceEpoch}-${randomToken(6)}.json';
    final payload = {
      'schema': 1,
      'batch_id': batchId,
      'resource_id': resourceId,
      'created_at': stamp.toIso8601String(),
      'message': text,
    };
    await files.writeBytes(
      uid: uid,
      batchId: batchId,
      relativePath: relativePath,
      bytes: utf8.encode(jsonEncode(payload)),
    );
    return relativePath;
  }
}
