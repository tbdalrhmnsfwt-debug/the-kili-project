import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// The home's one-row shortcut into the study library.
class LibraryShortcut extends StatelessWidget {
  const LibraryShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = featureAccentsOf(theme).study;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-library-shortcut'),
        borderRadius: ZakerRadius.card,
        onTap: () => context.push(ZakerRoutes.courses),
        child: Ink(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          decoration: BoxDecoration(
            color: cardSurfaceOf(theme),
            borderRadius: ZakerRadius.card,
            border: Border.all(color: ZakerColors.border),
            boxShadow: ZakerShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: 0.14),
                    cardSurfaceOf(theme),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    size: 22,
                    color: cardAccentOf(accent, theme),
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'المكتبة الدراسية',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TrText(
                      'كل الكتب والمناهج في مكان واحد',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
