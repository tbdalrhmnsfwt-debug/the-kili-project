/// Reads used by the local administration screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_store.dart';
import '../models/batch.dart';
import 'app_providers.dart';
import 'batch_providers.dart';

/// The newest-first local audit trail, after the batch access check.
final batchAuditProvider = FutureProvider.autoDispose
    .family<List<AuditEntry>, String>((ref, batchId) async {
  final uid = ref.watch(authUserProvider)?.uid ?? '';
  if (uid.isEmpty) return const <AuditEntry>[];
  // Reading the batch first keeps the membership check in one place.
  await ref.watch(batchDetailProvider(batchId).future);
  return ref.watch(batchRepositoryProvider).loadAudit(uid, batchId);
});

/// True when [uid] may open the admin screen: the owner or an admin.
bool canViewBatchAdmin(BatchSnapshot snapshot, String uid) {
  for (final member in snapshot.members) {
    if (member.uid != uid) continue;
    return member.role == BatchRole.owner || member.role == BatchRole.admin;
  }
  return false;
}

bool isBatchOwner(BatchSnapshot snapshot, String uid) =>
    snapshot.batch.ownerUid == uid;

/// A readable label for an audit action, without exposing any payload.
String auditActionLabel(String action) => switch (action) {
      'batchCreated' => 'إنشاء الدفعة',
      'batchClaimed' => 'نقل الدفعة لحساب',
      'settingsUpdated' => 'تغيير إعدادات الدفعة',
      'subjectAdded' => 'إضافة مادة',
      'subjectRenamed' => 'تغيير اسم مادة',
      'subjectDeleted' => 'حذف مادة',
      'resourceAdded' => 'إضافة ملف أو ملاحظة',
      'resourceDeleted' => 'حذف ملف أو ملاحظة',
      'resourceStarred' => 'تمييز ملف',
      'resourceUnstarred' => 'إلغاء تمييز ملف',
      'scheduleSaved' => 'حفظ جدول',
      'scheduleUpdated' => 'تعديل جدول',
      'schedulePublished' => 'نشر جدول',
      'scheduleDeleted' => 'حذف جدول',
      'updatePublished' => 'نشر مستجد',
      'updateEdited' => 'تعديل مستجد',
      'updateDeleted' => 'حذف مستجد',
      'examSaved' => 'حفظ امتحان',
      'examPublished' => 'نشر امتحان',
      'examAttemptStarted' => 'بدء محاولة امتحان',
      'examAttemptSubmitted' => 'تسليم محاولة امتحان',
      'chatMessageSent' => 'إرسال رسالة',
      'chatMessageEdited' => 'تعديل رسالة',
      'chatMessageDeleted' => 'حذف رسالة',
      'chatMessagePinned' => 'تثبيت رسالة',
      'chatMessageUnpinned' => 'إلغاء تثبيت رسالة',
      'codeRotated' => 'توليد كود دعوة جديد',
      'codeRevoked' => 'إيقاف كود الدعوة',
      _ => 'إجراء محلي',
    };
