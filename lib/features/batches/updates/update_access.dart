/// Reads the current member's role so update buttons match the repository.
///
/// Screens may hide controls, but every command re-checks the same matrix.
library;

import '../../../core/batches/batch_access.dart';
import '../../../core/batches/batch_store.dart';
import '../../../models/batch.dart';

BatchRole? updateRole(BatchSnapshot snapshot, String uid) {
  for (final member in snapshot.members) {
    if (member.uid == uid) return member.role;
  }
  return null;
}

bool canPostUpdates(BatchSnapshot snapshot, String uid) {
  final role = updateRole(snapshot, uid);
  return role != null && BatchAccess.can(role, BatchAction.postUpdate);
}

bool canManageUpdates(BatchSnapshot snapshot, String uid) {
  final role = updateRole(snapshot, uid);
  return role != null && BatchAccess.can(role, BatchAction.editAnyUpdate);
}
