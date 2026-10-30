import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import 'home_light_style.dart';

/// The greeting for a 24-hour clock [hour].
String greetingFor(int hour) => hour < 12 ? 'صباح الخير' : 'مساء الخير';

/// The home's free-text entry point.
///
/// The welcome card owns the greeting, so this widget is only the search
/// field: a white pill on the page background. Submitting it opens the chat
/// with the typed question.
class WelcomeSearch extends StatelessWidget {
  const WelcomeSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SearchPill();
  }
}

/// The white search pill. Submitting opens the AI chat with the typed
/// question; the blue arrow does the same for people who prefer a button.
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
      key: const Key('home-welcome-search'),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 7),
      decoration: BoxDecoration(
        color: HomeLight.surface,
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        boxShadow: HomeLight.shadow,
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAiSparkles,
            size: 19,
            color: HomeLight.blue,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              cursorColor: HomeLight.blue,
              style: const TextStyle(
                color: HomeLight.ink,
                fontFamily: ZakerTheme.fontUi,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
                hintText: 'اسأل معلم AI عن أي حاجة…',
                hintStyle: TextStyle(
                  color: HomeLight.muted,
                  fontFamily: ZakerTheme.fontUi,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
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
              // A 40 dp target around the 32 dp blue circle.
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [HomeLight.blue, HomeLight.blueDeep],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          size: 16,
                          color: Colors.white,
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
