/// Calculator errors shown on the display, modelled after the Casio error
/// classes (`Math ERROR`, `Syntax ERROR`, `Dimension ERROR`, …).
///
/// The message is deliberately a short calculator label; [hint] is a plain
/// explanation the UI can show under the input. Every error keeps the user's
/// input intact because the UI only replaces the result line.
library;

enum CalcErrorKind {
  syntax,
  math,
  dimension,
  stack,
  variable,
  argument,
  unsupported,
  empty,
}

/// A calculator input, domain, shape or capability error.
class CalcError implements Exception {
  const CalcError(this.kind, {this.detail});

  final CalcErrorKind kind;

  /// Optional technical detail. It is never shown instead of [label].
  final String? detail;

  /// The Casio-style label shown on the display.
  String get label => switch (kind) {
    CalcErrorKind.syntax => 'Syntax ERROR',
    CalcErrorKind.math => 'Math ERROR',
    CalcErrorKind.dimension => 'Dimension ERROR',
    CalcErrorKind.stack => 'Stack ERROR',
    CalcErrorKind.variable => 'Variable ERROR',
    CalcErrorKind.argument => 'Argument ERROR',
    CalcErrorKind.unsupported => 'Not Supported',
    CalcErrorKind.empty => 'Syntax ERROR',
  };

  /// A short, actionable hint. Arabic text so it fits the app's interface.
  String get hint => switch (kind) {
    CalcErrorKind.syntax =>
      'اتأكد من الأقواس والعمليات — مثال: ٢×(٣+٤).',
    CalcErrorKind.math =>
      'النتيجة مش معرّفة رياضيًا (قسمة على صفر أو خارج نطاق الدالة).',
    CalcErrorKind.dimension =>
      'أبعاد المصفوفة أو المتجه مش متوافقة مع العملية.',
    CalcErrorKind.stack =>
      'التعبير متداخل أكتر من المسموح — بسّطه لأجزاء أصغر.',
    CalcErrorKind.variable =>
      'المتغير مش معرّف أو الاسم مش صالح.',
    CalcErrorKind.argument =>
      'قيمة الدالة خارج النطاق أو نوع الوسيط غلط.',
    CalcErrorKind.unsupported =>
      'العملية دي مش مدعومة في النسخة المحلية، وجرب صيغة أبسط.',
    CalcErrorKind.empty => 'اكتب تعبير قبل ما تضغط =.',
  };

  @override
  String toString() => detail == null ? label : '$label ($detail)';
}
