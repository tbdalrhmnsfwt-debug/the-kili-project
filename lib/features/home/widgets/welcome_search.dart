import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// The greeting for a 24-hour clock [hour].
String greetingFor(int hour) => hour < 12 ? 'صباح الخير' : 'مساء الخير';

/// The navy welcome card: greeting, the gold question line, and the AI search.
///
/// The search is the app's free-text entry point; submitting it opens the chat
/// with the typed question.
class WelcomeSearch extends StatelessWidget {
  const WelcomeSearch({super.key, required this.name});

  /// The name shown after the greeting.
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-welcome-search'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: ZakerColors.navyGradient,
          stops: [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            '${greetingFor(DateTime.now().hour)}، $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          const TrText(
            'عايز تعمل إيه النهاردة؟',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ZakerColors.goldLight,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const _SearchPill(),
        ],
      ),
    );
  }
}

/// The translucent search pill. Submitting opens the AI chat with the typed
/// question.
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ShadInput(
              controller: _controller,
              decoration: ShadDecoration.none,
              padding: const EdgeInsets.symmetric(vertical: 13),
              cursorColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: ZakerTheme.fontUi,
                fontSize: 14,
              ),
              placeholder: const TrText(
                'اسأل معلم AI عن أي حاجة…',
                style: TextStyle(
                  color: Color(0xFFE3F4F2),
                  fontFamily: ZakerTheme.fontUi,
                  fontSize: 14,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
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
        ],
      ),
    );
  }
}
