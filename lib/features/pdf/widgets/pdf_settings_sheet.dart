/// The reader settings sheet.
///
/// Night mode, haptics and scroll direction; everything is persisted through
/// [pdfSettingsProvider]. No document content passes through here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/pdf_settings.dart';
import '../../../providers/pdf_providers.dart';
import '../../../widgets/tr_text.dart';

/// Opens the settings sheet.
Future<void> showPdfSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const PdfSettingsSheet(),
  );
}

/// The sheet body: switches and a scroll-direction control.
class PdfSettingsSheet extends ConsumerWidget {
  const PdfSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pdfSettingsProvider);
    final notifier = ref.read(pdfSettingsProvider.notifier);
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.sm,
              ZakerSpacing.lg,
              ZakerSpacing.md,
            ),
            child: TrText(
              'إعدادات القراءة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SwitchListTile(
            title: const TrText('وضع الليل'),
            subtitle: const TrText('بيهدّي لون الصفحة عشان عينك'),
            value: settings.nightMode,
            onChanged: notifier.setNightMode,
          ),
          SwitchListTile(
            title: const TrText('اهتزاز خفيف'),
            subtitle: const TrText('رجّة صغيرة لما تتقلّب الصفحة'),
            value: settings.haptics,
            onChanged: notifier.setHaptics,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.md,
              ZakerSpacing.lg,
              ZakerSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TrText('اتجاه التمرير'),
                const SizedBox(height: ZakerSpacing.sm),
                SegmentedButton<PdfScrollMode>(
                  segments: const [
                    ButtonSegment(
                      value: PdfScrollMode.vertical,
                      label: TrText('رأسي'),
                      icon: Icon(Icons.view_agenda_rounded),
                    ),
                    ButtonSegment(
                      value: PdfScrollMode.horizontal,
                      label: TrText('أفقي'),
                      icon: Icon(Icons.crop_portrait_rounded),
                    ),
                  ],
                  selected: {settings.scrollMode},
                  onSelectionChanged: (selection) =>
                      notifier.setScrollMode(selection.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
