/// Batch announcements shown on the local updates timeline.
library;

/// What kind of announcement a post is.
enum BatchUpdateKind { announcement, resource, schedule }

/// One announcement, authored on this device.
class BatchUpdate {
  const BatchUpdate({
    required this.id,
    required this.batchId,
    required this.authorUid,
    required this.authorName,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.kind,
    this.editedAt,
    this.pinned = false,
    this.readBy = const {},
    this.resourceId,
  });

  final String id;
  final String batchId;
  final String authorUid;
  final String authorName;
  final String title;
  final String body;
  final DateTime createdAt;
  final BatchUpdateKind kind;
  final DateTime? editedAt;
  final bool pinned;

  /// Uids who have opened this post on this device.
  final Set<String> readBy;

  /// Set when the post announces a resource that still exists.
  final String? resourceId;

  bool isReadBy(String uid) => readBy.contains(uid);

  BatchUpdate copyWith({
    String? title,
    String? body,
    DateTime? editedAt,
    bool? pinned,
    Set<String>? readBy,
  }) =>
      BatchUpdate(
        id: id,
        batchId: batchId,
        authorUid: authorUid,
        authorName: authorName,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        kind: kind,
        editedAt: editedAt ?? this.editedAt,
        pinned: pinned ?? this.pinned,
        readBy: readBy ?? this.readBy,
        resourceId: resourceId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'authorUid': authorUid,
        'authorName': authorName,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind.name,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        'pinned': pinned,
        if (readBy.isNotEmpty) 'readBy': readBy.toList(),
        if (resourceId != null) 'resourceId': resourceId,
      };

  factory BatchUpdate.fromJson(Map<String, dynamic> json) => BatchUpdate(
        id: json['id'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        authorUid: json['authorUid'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        kind: switch (json['kind'] as String?) {
          'resource' => BatchUpdateKind.resource,
          'schedule' => BatchUpdateKind.schedule,
          _ => BatchUpdateKind.announcement,
        },
        editedAt: DateTime.tryParse(json['editedAt'] as String? ?? ''),
        pinned: json['pinned'] as bool? ?? false,
        readBy: {...?(json['readBy'] as List?)?.whereType<String>()},
        resourceId: json['resourceId'] as String?,
      );
}
