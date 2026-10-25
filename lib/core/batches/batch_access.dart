/// The single authorization matrix for batch commands.
///
/// Screens may hide controls, but every repository command re-checks this
/// matrix. The policy is default-deny: an action is allowed only when the
/// role appears in its explicit set.
library;

import '../../models/batch.dart';

/// A command a member may attempt.
enum BatchAction {
  viewBatch,
  viewMembers,
  viewChat,
  sendMessage,
  deleteOwnMessage,
  deleteAnyMessage,
  react,
  pinMessage,
  viewResources,
  uploadResource,
  deleteOwnResource,
  deleteAnyResource,
  starResource,
  viewUpdates,
  postUpdate,
  editAnyUpdate,
  deleteAnyUpdate,
  viewSchedules,
  importTimetable,
  editTimetable,
  viewExams,
  createExam,
  publishExam,
  gradeExam,
  takeExam,
  viewResults,
  manageSubjects,
  editBatch,
  deleteBatch,
  manageSettings,
  viewInviteCode,
  rotateInviteCode,
  revokeInviteCode,
  manageMembers,
  approveJoinRequest,
  rejectJoinRequest,
  muteMember,
  removeMember,
  viewAudit,
  exportData,
}

/// Pure role × action checks.
class BatchAccess {
  const BatchAccess._();

  /// Readers may see the batch and its content but cannot write.
  static const Set<BatchRole> _readers = {
    BatchRole.owner,
    BatchRole.admin,
    BatchRole.member,
    BatchRole.muted,
  };

  /// Active members may see every content area.
  static const Set<BatchAction> _readActions = {
    BatchAction.viewBatch,
    BatchAction.viewMembers,
    BatchAction.viewChat,
    BatchAction.viewResources,
    BatchAction.viewUpdates,
    BatchAction.viewSchedules,
    BatchAction.viewExams,
    BatchAction.viewResults,
  };

  /// What an admin may do on top of reading.
  static const Set<BatchAction> _adminActions = {
    ..._readActions,
    BatchAction.sendMessage,
    BatchAction.deleteOwnMessage,
    BatchAction.deleteAnyMessage,
    BatchAction.react,
    BatchAction.pinMessage,
    BatchAction.uploadResource,
    BatchAction.deleteOwnResource,
    BatchAction.deleteAnyResource,
    BatchAction.starResource,
    BatchAction.postUpdate,
    BatchAction.editAnyUpdate,
    BatchAction.deleteAnyUpdate,
    BatchAction.importTimetable,
    BatchAction.editTimetable,
    BatchAction.createExam,
    BatchAction.publishExam,
    BatchAction.gradeExam,
    BatchAction.takeExam,
    BatchAction.manageSubjects,
    BatchAction.editBatch,
    BatchAction.manageMembers,
    BatchAction.approveJoinRequest,
    BatchAction.rejectJoinRequest,
    BatchAction.muteMember,
    BatchAction.removeMember,
    BatchAction.viewAudit,
    BatchAction.exportData,
  };

  /// What an ordinary member may do.
  static const Set<BatchAction> _memberActions = {
    ..._readActions,
    BatchAction.sendMessage,
    BatchAction.deleteOwnMessage,
    BatchAction.react,
    BatchAction.uploadResource,
    BatchAction.deleteOwnResource,
    BatchAction.starResource,
    BatchAction.takeExam,
  };

  /// Muted members keep read access and lose every write.
  static const Set<BatchAction> _mutedActions = _readActions;

  static bool can(BatchRole role, BatchAction action) {
    if (role == BatchRole.removed) return false;
    // A pending request has no membership yet, so it grants nothing.
    if (role == BatchRole.pending) return false;
    if (role == BatchRole.owner) return true;
    final allowed = switch (role) {
      BatchRole.admin => _adminActions,
      BatchRole.member => _memberActions,
      BatchRole.muted => _mutedActions,
      _ => const <BatchAction>{},
    };
    return allowed.contains(action);
  }

  /// True for roles that can read batch content.
  static bool isReader(BatchRole role) => _readers.contains(role);

  /// True for roles that may write at least something.
  static bool canWrite(BatchRole role) =>
      role == BatchRole.owner ||
      role == BatchRole.admin ||
      role == BatchRole.member;

  /// Cross-batch isolation: a record may be read only through the batch that
  /// owns it.
  static bool belongsToBatch({
    required String requestedBatchId,
    required String recordBatchId,
  }) {
    if (requestedBatchId.isEmpty || recordBatchId.isEmpty) return false;
    return requestedBatchId == recordBatchId;
  }
}
