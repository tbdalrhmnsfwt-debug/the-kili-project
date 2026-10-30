import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'rafiq_brand.dart';
import 'rafiq_mark.dart';

/// Shows the brand over the app on first launch, then gets out of the way.
///
/// The gate keeps `child` built the whole time and only draws an overlay on
/// top, so the app's own start-up work is not delayed by the splash. It runs
/// once per process: a rebuild reuses the state and never replays.
class RafiqSplashGate extends StatefulWidget {
  const RafiqSplashGate({
    super.key,
    required this.child,
    this.animationsDisabled,
    this.fadeIn = const Duration(milliseconds: 450),
    this.hold = const Duration(milliseconds: 700),
    this.fadeOut = const Duration(milliseconds: 400),
  });

  final Widget child;

  /// Overrides the platform switch; null reads the platform's setting.
  final bool? animationsDisabled;

  final Duration fadeIn;
  final Duration hold;
  final Duration fadeOut;

  @override
  State<RafiqSplashGate> createState() => _RafiqSplashGateState();
}

class _RafiqSplashGateState extends State<RafiqSplashGate> {
  late final bool _reducedMotion;
  late final Duration _fadeIn;
  late final Duration _hold;
  late final Duration _fadeOut;

  Duration _fadeDuration = Duration.zero;

  /// The overlay paints navy from the very first frame so the app underneath
  /// never flashes between the native launch screen and the brand.
  double _overlayOpacity = 1;
  double _contentOpacity = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reducedMotion = widget.animationsDisabled ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    _fadeIn =
        _reducedMotion ? const Duration(milliseconds: 120) : widget.fadeIn;
    _hold = _reducedMotion ? Duration.zero : widget.hold;
    _fadeOut =
        _reducedMotion ? const Duration(milliseconds: 120) : widget.fadeOut;
    _fadeDuration = _fadeIn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run());
    });
  }

  Future<void> _run() async {
    if (!mounted) return;
    // The mark and copy fade in over the always-opaque navy surface.
    setState(() => _contentOpacity = 1);
    await Future<void>.delayed(_fadeIn);
    if (!mounted) return;
    await Future<void>.delayed(_hold);
    if (!mounted) return;
    setState(() {
      _fadeDuration = _fadeOut;
      _overlayOpacity = 0;
    });
    await Future<void>.delayed(_fadeOut);
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          widget.child,
          if (!_done)
            Positioned.fill(
              child: AbsorbPointer(
                child: AnimatedOpacity(
                  key: const Key('rafiq-splash'),
                  opacity: _overlayOpacity,
                  duration: _fadeDuration,
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _contentOpacity,
                    duration: _fadeIn,
                    curve: Curves.easeOut,
                    child: _SplashBody(
                      reducedMotion: _reducedMotion,
                      progress: _contentOpacity,
                      fadeDuration: _fadeIn,
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

class _SplashBody extends StatelessWidget {
  const _SplashBody({
    required this.reducedMotion,
    required this.progress,
    required this.fadeDuration,
  });

  final bool reducedMotion;
  final double progress;
  final Duration fadeDuration;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontFamily: ZakerTheme.fontUi,
      color: Colors.white,
      fontSize: 15,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ZakerColors.navy,
            ZakerColors.navyLight,
            ZakerColors.navyDeep,
          ],
        ),
      ),
      child: DefaultTextStyle(
        style: textStyle,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: reducedMotion ? 1 : 0.92 + 0.08 * progress,
                  duration: fadeDuration,
                  curve: Curves.easeOut,
                  child: const RafiqMark(size: 96),
                ),
                const SizedBox(height: 20),
                const Text(
                  RafiqBrand.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: ZakerTheme.fontUi,
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  RafiqBrand.credit,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: ZakerTheme.fontUi,
                    color: ZakerColors.goldLight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
