/// Core batch, membership and audit models.
///
/// The app is local-first: a batch lives on one device and belongs to one
/// account. The role and membership types are complete anyway, because they
/// are the contract a future server implements and the access matrix is
/// tested against every role.
library;

/// A member's role in a batch.
enum BatchRole { owner, admin, member, pending, muted, removed }

/// Who receives update notifications.
enum BatchNotificationDetail { generic, titled }

/// Settings the owner controls.
class BatchSettings {
  const BatchSettings({
    this.uploadsAdminOnly = true,
    this.requireApproval = true,
    this.allowMemberReminders = true,
    this.notificationDetail = BatchNotificationDetail.generic,
  });

  final bool uploadsAdminOnly;
  final bool requireApproval;
  final bool allowMemberReminders;
  final BatchNotificationDetail notificationDetail;

  BatchSettings copyWith({
    bool? uploadsAdminOnly,
    bool? requireApproval,
    bool? allowMemberReminders,
    BatchNotificationDetail? notificationDetail,
  }) =>
      BatchSettings(
        uploadsAdminOnly: uploadsAdminOnly ?? this.uploadsAdminOnly,
        requireApproval: requireApproval ?? this.requireApproval,
        allowMemberReminders: allowMemberReminders ?? this.allowMemberReminders,
        notificationDetail: notificationDetail ?? this.notificationDetail,
      );

  Map<String, dynamic> toJson() => {
        'uploadsAdminOnly': uploadsAdminOnly,
        'requireApproval': requireApproval,
        'allowMemberReminders': allowMemberReminders,
        'notificationDetail': notificationDetail.name,
      };

  factory BatchSettings.fromJson(Map<String, dynamic> json) => BatchSettings(
        uploadsAdminOnly: json['uploadsAdminOnly'] as bool? ?? true,
        requireApproval: json['requireApproval'] as bool? ?? true,
        allowMemberReminders: json['allowMemberReminders'] as bool? ?? true,
        notificationDetail: switch (json['notificationDetail'] as String?) {
          'titled' => BatchNotificationDetail.titled,
          _ => BatchNotificationDetail.generic,
        },
      );
}

/// One subject inside a batch.
class BatchSubject {
  const BatchSubject({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int order;
  final DateTime createdAt;

  BatchSubject copyWith({String? name, int? order}) => BatchSubject(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BatchSubject.fromJson(Map<String, dynamic> json) => BatchSubject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// The state of the eight-digit invitation code.
class InviteCodeState {
  const InviteCodeState({
    required this.code,
    required this.createdAt,
    this.rotatedAt,
    this.revokedAt,
    this.rotationCount = 0,
  });

  final String code;
  final DateTime createdAt;
  final DateTime? rotatedAt;
  final DateTime? revokedAt;
  final int rotationCount;

  bool get isActive => code.isNotEmpty && revokedAt == null;

  InviteCodeState copyWith({
    String? code,
    DateTime? rotatedAt,
    DateTime? revokedAt,
    int? rotationCount,
  }) =>
      InviteCodeState(
        code: code ?? this.code,
        createdAt: createdAt,
        rotatedAt: rotatedAt ?? this.rotatedAt,
        revokedAt: revokedAt ?? this.revokedAt,
        rotationCount: rotationCount ?? this.rotationCount,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'createdAt': createdAt.toIso8601String(),
        if (rotatedAt != null) 'rotatedAt': rotatedAt!.toIso8601String(),
        if (revokedAt != null) 'revokedAt': revokedAt!.toIso8601String(),
        'rotationCount': rotationCount,
      };

  factory InviteCodeState.fromJson(Map<String, dynamic> json) =>
      InviteCodeState(
        code: json['code'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        rotatedAt: DateTime.tryParse(json['rotatedAt'] as String? ?? ''),
        revokedAt: DateTime.tryParse(json['revokedAt'] as String? ?? ''),
        rotationCount: (json['rotationCount'] as num?)?.toInt() ?? 0,
      );
}

/// A batch and its subjects/settings/code.
class Batch {
  const Batch({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    required this.settings,
    required this.subjects,
    required this.codeState,
    this.archivedAt,
    this.lastActivityAt,
  });

  final String id;
  final String name;
  final String ownerUid;
  final DateTime createdAt;
  final BatchSettings settings;
  final List<BatchSubject> subjects;
  final InviteCodeState codeState;
  final DateTime? archivedAt;
  final DateTime? lastActivityAt;

  Batch copyWith({
    String? name,
    String? ownerUid,
    BatchSettings? settings,
    List<BatchSubject>? subjects,
    InviteCodeState? codeState,
    DateTime? lastActivityAt,
  }) =>
      Batch(
        id: id,
        name: name ?? this.name,
        ownerUid: ownerUid ?? this.ownerUid,
        createdAt: createdAt,
        settings: settings ?? this.settings,
        subjects: subjects ?? this.subjects,
        codeState: codeState ?? this.codeState,
        archivedAt: archivedAt,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
        'settings': settings.toJson(),
        'subjects': [for (final subject in subjects) subject.toJson()],
        'codeState': codeState.toJson(),
        if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
        if (lastActivityAt != null)
          'lastActivityAt': lastActivityAt!.toIso8601String(),
      };

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        ownerUid: json['ownerUid'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        settings: json['settings'] is Map
            ? BatchSettings.fromJson(
                Map<String, dynamic>.from(json['settings'] as Map),
              )
            : const BatchSettings(),
        subjects: [
          for (final raw in (json['subjects'] as List? ?? const []))
            if (raw is Map)
              BatchSubject.fromJson(Map<String, dynamic>.from(raw)),
        ],
        codeState: json['codeState'] is Map
            ? InviteCodeState.fromJson(
                Map<String, dynamic>.from(json['codeState'] as Map),
              )
            : InviteCodeState(
                code: '',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
        archivedAt: DateTime.tryParse(json['archivedAt'] as String? ?? ''),
        lastActivityAt:
            DateTime.tryParse(json['lastActivityAt'] as String? ?? ''),
      );
}

/// A membership row. Locally only the owner exists, but the type is the
/// future-server contract and the access tests exercise every role.
class Membership {
  const Membership({
    required this.batchId,
    required this.uid,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.removedAt,
  });

  final String batchId;
  final String uid;
  final String displayName;
  final BatchRole role;
  final DateTime joinedAt;
  final DateTime? removedAt;

  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'uid': uid,
        'displayName': displayName,
        'role': role.name,
        'joinedAt': joinedAt.toIso8601String(),
        if (removedAt != null) 'removedAt': removedAt!.toIso8601String(),
      };

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        batchId: json['batchId'] as String? ?? '',
        uid: json['uid'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        role: switch (json['role'] as String?) {
          'owner' => BatchRole.owner,
          'admin' => BatchRole.admin,
          'pending' => BatchRole.pending,
          'muted' => BatchRole.muted,
          'removed' => BatchRole.removed,
          _ => BatchRole.member,
        },
        joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        removedAt: DateTime.tryParse(json['removedAt'] as String? ?? ''),
      );
}

/// One local audit record. Details never contain message text, answers,
/// transcripts, codes or file paths.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.batchId,
    required this.actorUid,
    required this.action,
    required this.at,
    this.detail = '',
  });

  final String id;
  final String batchId;
  final String actorUid;
  final String action;
  final DateTime at;
  final String detail;

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'actorUid': actorUid,
        'action': action,
        'at': at.toIso8601String(),
        if (detail.isNotEmpty) 'detail': detail,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        actorUid: json['actorUid'] as String? ?? '',
        action: json['action'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        detail: json['detail'] as String? ?? '',
      );
}
