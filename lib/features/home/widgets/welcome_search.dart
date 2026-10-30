import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';
import 'home_style.dart';

/// The greeting for a 24-hour clock [hour].
String greetingFor(int hour) => hour < 12 ? 'صباح الخير' : 'مساء الخير';

/// The greeting and AI question line that sit under the prayer badge.
///
/// The navy gradient belongs to the header that owns this widget, so the
/// welcome content stays transparent and can be reused inside the compact
/// header without a nested card. The search is the app's free-text entry point;
/// submitting it opens the chat with the typed question.
class WelcomeSearch extends StatelessWidget {
  const WelcomeSearch({super.key, required this.name});

  /// The name shown after the greeting.
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-welcome-search'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomePalette.champagneLight, HomePalette.champagne],
                ),
                borderRadius: BorderRadius.circular(ZakerRadius.pill),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrText(
                    '${greetingFor(DateTime.now().hour)}، $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomePalette.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const TrText(
                    'عايز تعمل إيه النهاردة؟',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomePalette.champagneLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SearchPill(),
      ],
    );
  }
}

/// The translucent search pill. Submitting opens the AI chat with the typed
/// question; the gold arrow does the same for people who prefer a button.
class _SearchPill extends StatefulWidget {
  const _SearchPill();

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    context.push('${ZakerRoutes.chat}?q=${Uri.encodeQueryComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(
          color: HomePalette.champagne.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: HomePalette.emerald.withValues(alpha: 0.08),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAiSparkles,
            size: 19,
            color: HomePalette.champagneLight,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: ShadInput(
              controller: _controller,
              decoration: ShadDecoration.none,
              padding: const EdgeInsets.symmetric(vertical: 11),
              cursorColor: Colors.white,
              style: const TextStyle(
                color: HomePalette.textPrimary,
                fontFamily: ZakerTheme.fontUi,
                fontSize: 13.5,
              ),
              placeholder: const TrText(
                'اسأل معلم AI عن أي حاجة…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomePalette.textSecondary,
                  fontFamily: ZakerTheme.fontUi,
                  fontSize: 13.5,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'اسأل معلم AI',
            child: SizedBox(
              // A 40 dp target around the 32 dp gold circle.
              width: 40,
              height: 40,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('home-search-submit'),
                  customBorder: const CircleBorder(),
                  onTap: () => _submit(_controller.text),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            HomePalette.champagneLight,
                            HomePalette.champagne,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: HomePalette.champagne.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          size: 16,
                          color: HomePalette.midnight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
