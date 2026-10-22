/// The mutashabihat (similar-words) browser.
///
/// The dataset ships as `assets/quran/mutashabihat.json.gz` with the
/// structure recovered from the APK:
/// ```json
/// {
///   "version": 3, "built": "2026-09-13",
///   "sources": ["qurani.ai", "qul.tarteel.ai"],
///   "meta": {...},
///   "phrases": [ {"t": "…", "o": [["2:23", 15, 17, "both", "A"], …]} ],
///   "pairs":  { "101:6": [["1503", "7:8"]] },
///   "similar":{ "1:1":  [ {"k": "27:30", "s": 80, "c": 50, …} ] },
///   "popular":["2:3", "8:3", …]
/// }
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Browses the mutashabihat dataset.
class MutashabihatScreen extends ConsumerWidget {
  const MutashabihatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(assetServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText(ZakerStrings.s_1692c)), // متشابهات السورة
      body: FutureBuilder(
        future: service.loadMutashabihat(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingBox();
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: ZakerStrings.s_0_ef5cc, // مافيش متشابهات في {0}
              message: snapshot.error?.toString() ?? '',
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return EmptyState(
              icon: Icons.compare_arrows_rounded,
              title: ZakerStrings.s_be531, // المتشابهات
              message: ZakerStrings.s_916c7, // والفرق بين الحاجات اللي بتتلخبط مع بعض.
            );
          }
          return ListView(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            children: [
              Wrap(
                spacing: ZakerSpacing.sm,
                runSpacing: ZakerSpacing.sm,
                children: [
                  StatChip(
                    value: '${data.phraseTiersCount['A'] ?? 0}',
                    label: ZakerStrings.s_f219b, // المصدر كله
                    icon: Icons.local_fire_department_rounded,
                    color: ZakerColors.accent,
                  ),
                  StatChip(
                    value: '${data.phraseTiersCount['B'] ?? 0}',
                    label: 'عبارة (B)',
                    icon: Icons.layers_rounded,
                  ),
                  StatChip(
                    value: '${data.occurrenceTiersCount['A'] ?? 0}',
                    label: ZakerStrings.s_b564a, // إيه الفرق بين
                    icon: Icons.repeat_rounded,
                    color: ZakerColors.primaryLight,
                  ),
                  StatChip(
                    value: '${data.similarTiersCount['B'] ?? 0}',
                    label: ZakerStrings.s_ed57f, // اسمع الفرق
                    icon: Icons.link_rounded,
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.lg),
              TrText(
                ZakerStrings.s_30071, // جداول الفروق بين المتشابهات
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                'المصدر: ${data.sourceFiles.join('، ')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                'تاريخ البناء: ${data.builtAt}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
