/// Typed failures shared by the batch services and screens.
library;

/// Every failure the batch layer may report. UI maps each to Arabic copy.
enum BatchFailureCode {
  invalidName,
  invalidSubject,
  invalidCode,
  codeCooldown,
  codeNotFound,
  codeRevoked,
  alreadyMember,
  pendingUnsupported,
  notAuthorized,
  claimFailed,
  missingFile,
  unsupportedFile,
  fileTooLarge,
  storageFull,
  corruptStore,
  migrationUnsupported,
  permissionDenied,
  ocrFailed,
  ocrLowConfidence,
  extractionFailed,
  encryptedSource,
  tooManyPages,
  examNotOpen,
  examClosed,
  examWindowInvalid,
  transcriptionUnavailable,
  remoteRequired,
  cancelled,
  validationFailed,
  notFound,
  conflict,
}

/// A capability that genuinely needs a server or an on-device model this
/// build does not ship. Screens render these with a reason and the local
/// alternative, never with a fake success.
enum BlockedCapability {
  crossDeviceJoin,
  joinApproval,
  memberManagement,
  moderation,
  realtimeDelivery,
  pushNotifications,
  remoteStorage,
  liveChallenge,
  crossMemberRanking,
  serverTime,
  transcription,
  remoteAi,
}

/// A failed batch command.
class BatchFailure implements Exception {
  const BatchFailure(this.code, {this.field, this.detail, this.blocked});

  const BatchFailure.blocked(this.blocked)
      : code = BatchFailureCode.remoteRequired,
        field = null,
        detail = null;

  final BatchFailureCode code;

  /// The form field at fault, when the failure came from validation.
  final String? field;

  /// A developer-facing note. Never contains message text, answers, codes or
  /// file paths.
  final String? detail;

  /// Set when the operation is blocked rather than invalid.
  final BlockedCapability? blocked;

  bool get isBlocked => blocked != null;

  @override
  String toString() {
    final suffix = detail == null ? '' : ' ($detail)';
    return 'BatchFailure(${code.name}$suffix)';
  }
}
