/// Notes / notebooks model.
///
/// The shipped strings describe per-subject notebooks with pages:
/// `دفتر ملاحظاتك جوه التطبيق — تكتب فيه وتنظم وترجعله وقت المراجعة.`
/// `رياضيات، عربي، علوم… كل مادة نوتة مستقلة`
library;

import 'dart:convert';

/// A single page inside a [Notebook].
class NotebookPage {
  const NotebookPage({
    required this.id,
    required this.body,
    this.title = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String body;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// A crude quality score: longer notes score higher, capped at 100.
  int get quality {
    final words = body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words * 2).clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        if (title.isNotEmpty) 'title': title,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory NotebookPage.fromJson(Map<String, dynamic> json) => NotebookPage(
        id: json['id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        title: json['title'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}

/// A notebook, usually one per subject.
class Notebook {
  const Notebook({
    required this.id,
    required this.subject,
    List<NotebookPage>? pages,
    this.createdAt,
  }) : pages = pages ?? const <NotebookPage>[];

  final String id;

  /// The subject this notebook belongs to, e.g. `الرياضيات`.
  final String subject;

  final List<NotebookPage> pages;
  final DateTime? createdAt;

  int get wordCount => pages.fold<int>(
    0,
    (s, p) => s + p.body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'pages': pages.map((p) => p.toJson()).toList(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory Notebook.fromJson(Map<String, dynamic> json) => Notebook(
        id: json['id'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        pages: ((json['pages'] as List?) ?? const [])
            .map((e) => NotebookPage.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );
}

/// Encodes the notebooks for persistence.
String encodeNotebooks(List<Notebook> notebooks) => jsonEncode({
      'notebooks': notebooks.map((n) => n.toJson()).toList(),
    });

/// Decodes notebooks persisted by [encodeNotebooks].
List<Notebook> decodeNotebooks(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ((json['notebooks'] as List?) ?? const [])
      .map((e) => Notebook.fromJson(e as Map<String, dynamic>))
      .toList();
}
