/// Providers for the PDF library and reader.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pdf/pdf_render_channel.dart';

/// The native tile renderer. Overridden in tests with a fake.
final pdfRenderChannelProvider = Provider<PdfRenderChannel>(
  (ref) => const PdfRenderChannel(),
);
