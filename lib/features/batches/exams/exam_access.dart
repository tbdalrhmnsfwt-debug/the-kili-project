/// Who may author, publish and take exams.
library;

import '../../../core/batches/batch_access.dart';
import '../../../core/batches/batch_store.dart';
import '../../../models/batch.dart';

/// The role an account holds in [snapshot], or null when it is not a member.
BatchRole? examRole(BatchSnapshot snapshot, String uid) {
  for (final member in snapshot.members) {
    if (member.uid == uid) return member.role;
  }
  return null;
}

/// Owner and admins author and publish exams.
bool canAuthorExams(BatchSnapshot snapshot, String uid) {
  final role = examRole(snapshot, uid);
  return role != null && BatchAccess.can(role, BatchAction.createExam);
}

/// Only owner and admins may publish.
bool canPublishExams(BatchSnapshot snapshot, String uid) {
  final role = examRole(snapshot, uid);
  return role != null && BatchAccess.can(role, BatchAction.publishExam);
}

/// Active members may start and submit attempts. A muted member may still read
/// their earlier results through [BatchAction.viewResults].
bool canTakeExams(BatchSnapshot snapshot, String uid) {
  final role = examRole(snapshot, uid);
  return role != null && BatchAccess.can(role, BatchAction.takeExam);
}
