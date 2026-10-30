import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_access.dart';
import 'package:zaker_ai/models/batch.dart';

void main() {
  group('BatchAccess', () {
    test('the owner may attempt every action', () {
      for (final action in BatchAction.values) {
        expect(
          BatchAccess.can(BatchRole.owner, action),
          isTrue,
          reason: 'owner should be allowed: ${action.name}',
        );
      }
    });

    test('a removed member may do nothing', () {
      for (final action in BatchAction.values) {
        expect(
          BatchAccess.can(BatchRole.removed, action),
          isFalse,
          reason: 'removed should be denied: ${action.name}',
        );
      }
    });

    test('a pending request grants no read or write', () {
      for (final action in BatchAction.values) {
        expect(
          BatchAccess.can(BatchRole.pending, action),
          isFalse,
          reason: 'pending should be denied: ${action.name}',
        );
      }
    });

    test('a muted member can read but cannot write', () {
      expect(BatchAccess.can(BatchRole.muted, BatchAction.viewChat), isTrue);
      expect(
        BatchAccess.can(BatchRole.muted, BatchAction.viewResources),
        isTrue,
      );
      expect(
        BatchAccess.can(BatchRole.muted, BatchAction.sendMessage),
        isFalse,
      );
      expect(BatchAccess.can(BatchRole.muted, BatchAction.react), isFalse);
      expect(
        BatchAccess.can(BatchRole.muted, BatchAction.uploadResource),
        isFalse,
      );
      expect(BatchAccess.can(BatchRole.muted, BatchAction.takeExam), isFalse);
      expect(BatchAccess.can(BatchRole.muted, BatchAction.viewAudit), isFalse);
    });

    test('an ordinary member is denied admin commands', () {
      const denied = [
        BatchAction.manageSettings,
        BatchAction.deleteBatch,
        BatchAction.rotateInviteCode,
        BatchAction.revokeInviteCode,
        BatchAction.viewInviteCode,
        BatchAction.viewAudit,
        BatchAction.pinMessage,
        BatchAction.deleteAnyMessage,
        BatchAction.deleteAnyResource,
        BatchAction.createExam,
        BatchAction.publishExam,
        BatchAction.manageSubjects,
        BatchAction.manageMembers,
        BatchAction.removeMember,
        BatchAction.editBatch,
        BatchAction.postUpdate,
      ];
      for (final action in denied) {
        expect(
          BatchAccess.can(BatchRole.member, action),
          isFalse,
          reason: 'member should be denied: ${action.name}',
        );
      }
    });

    test('an ordinary member keeps personal and reading actions', () {
      const allowed = [
        BatchAction.viewBatch,
        BatchAction.viewMembers,
        BatchAction.viewChat,
        BatchAction.viewResources,
        BatchAction.viewUpdates,
        BatchAction.viewSchedules,
        BatchAction.viewExams,
        BatchAction.viewResults,
        BatchAction.sendMessage,
        BatchAction.deleteOwnMessage,
        BatchAction.react,
        BatchAction.uploadResource,
        BatchAction.deleteOwnResource,
        BatchAction.starResource,
        BatchAction.takeExam,
      ];
      for (final action in allowed) {
        expect(
          BatchAccess.can(BatchRole.member, action),
          isTrue,
          reason: 'member should be allowed: ${action.name}',
        );
      }
    });

    test('an admin may moderate but not own the batch', () {
      expect(BatchAccess.can(BatchRole.admin, BatchAction.pinMessage), isTrue);
      expect(BatchAccess.can(BatchRole.admin, BatchAction.viewAudit), isTrue);
      expect(
        BatchAccess.can(BatchRole.admin, BatchAction.removeMember),
        isTrue,
      );
      expect(BatchAccess.can(BatchRole.admin, BatchAction.publishExam), isTrue);
      expect(
        BatchAccess.can(BatchRole.admin, BatchAction.deleteBatch),
        isFalse,
      );
      expect(
        BatchAccess.can(BatchRole.admin, BatchAction.manageSettings),
        isFalse,
      );
      expect(
        BatchAccess.can(BatchRole.admin, BatchAction.rotateInviteCode),
        isFalse,
      );
      expect(
        BatchAccess.can(BatchRole.admin, BatchAction.viewInviteCode),
        isFalse,
      );
    });

    test('readers and writers are classified consistently', () {
      for (final role in BatchRole.values) {
        if (BatchAccess.isReader(role)) {
          expect(BatchAccess.can(role, BatchAction.viewBatch), isTrue);
        } else {
          expect(BatchAccess.can(role, BatchAction.viewBatch), isFalse);
        }
      }
      expect(BatchAccess.canWrite(BatchRole.owner), isTrue);
      expect(BatchAccess.canWrite(BatchRole.admin), isTrue);
      expect(BatchAccess.canWrite(BatchRole.member), isTrue);
      expect(BatchAccess.canWrite(BatchRole.muted), isFalse);
      expect(BatchAccess.canWrite(BatchRole.pending), isFalse);
      expect(BatchAccess.canWrite(BatchRole.removed), isFalse);
    });

    test('a record belongs only to its own batch', () {
      expect(
        BatchAccess.belongsToBatch(requestedBatchId: 'b1', recordBatchId: 'b1'),
        isTrue,
      );
      expect(
        BatchAccess.belongsToBatch(requestedBatchId: 'b1', recordBatchId: 'b2'),
        isFalse,
      );
      expect(
        BatchAccess.belongsToBatch(requestedBatchId: '', recordBatchId: ''),
        isFalse,
      );
    });
  });
}
