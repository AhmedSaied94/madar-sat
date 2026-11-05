import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'logo.dart';

/// Shows [BrandSplash] over [child] once per cold start, then gets out of the way.
///
/// [child] builds underneath from the first frame, so the splash never delays the first
/// screen's data. The animation carries no timer: tests can settle it.
class BrandSplashGate extends StatefulWidget {
  const BrandSplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<BrandSplashGate> createState() => _BrandSplashGateState();
}

class _BrandSplashGateState extends State<BrandSplashGate>
    with SingleTickerProviderStateMixin {
  static const Duration _full = Duration(milliseconds: 2100);
  static const Duration _reduced = Duration(milliseconds: 900);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _full,
  )..addStatusListener(_onStatus);
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.duration = _reduced;
    }
    unawaited(_controller.forward());
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _done = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          AbsorbPointer(
            child: ExcludeSemantics(child: BrandSplash(progress: _controller)),
          ),
      ],
    );
  }
}

/// The app's own splash (product doc S0), always dark: the mark sits where the system splash
/// left it, the satellite circles the planet, and the name and the tagline rise in below.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key, required this.progress});

  /// 0 to 1 across the whole splash, its fade-out included.
  final Animation<double> progress;

  /// The native icon's rings and mark: the Play icon's 512-unit art at this many dp, which is
  /// how large Android 12 draws the adaptive foreground.
  static const double _artSide = 192;

  /// The mark's 32-unit grid is 400 of the art's 512 units (`generate_launcher_icons.sh`).
  static const double _markSide = _artSide * 400 / 512;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const colors = MadarColors.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    final Animation<double> orbit = still
        ? const AlwaysStoppedAnimation<double>(0)
        : CurvedAnimation(
            parent: progress,
            curve: const Interval(0, 0.86, curve: Curves.easeInOutCubic),
          );
    final copyIn = CurvedAnimation(
      parent: progress,
      curve: const Interval(0.04, 0.3, curve: Curves.easeOut),
    );
    final fadeOut = ReverseAnimation(
      CurvedAnimation(parent: progress, curve: const Interval(0.88, 1)),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: ColoredBox(
        color: colors.bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copyTop =
                constraints.maxHeight / 2 + _artSide / 2 + MadarSpace.s6;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RingsPainter(color: colors.surface2),
                  ),
                ),
                Center(
                  child: SizedBox.square(
                    dimension: _markSide,
                    child: CustomPaint(
                      painter: MadarMarkPainter(
                        ring: colors.accent,
                        body: colors.textPrimary,
                        orbit: orbit,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: copyTop,
                  left: MadarSpace.s6,
                  right: MadarSpace.s6,
                  child: FadeTransition(
                    opacity: still
                        ? const AlwaysStoppedAnimation<double>(1)
                        : copyIn,
                    child: _SplashCopy(
                      name: l.appName,
                      question: l.splashQuestion,
                      answer: l.splashAnswer,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SplashCopy extends StatelessWidget {
  const _SplashCopy({
    required this.name,
    required this.question,
    required this.answer,
  });

  final String name;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    const colors = MadarColors.dark;
    final line = MadarText.textBody.copyWith(color: colors.textSecondary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          textAlign: TextAlign.center,
          style: MadarText.kickoff.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: MadarSpace.s3),
        Text(question, textAlign: TextAlign.center, style: line),
        Text(answer, textAlign: TextAlign.center, style: line),
      ],
    );
  }
}

/// The hairline rings around the mark: the native icon's two, then two wider for atmosphere.
class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.color});

  final Color color;

  /// Radii in dp, from the Play icon (245 and 210 of 512) and the design's splash board.
  static const List<double> _radii = [79, 92, 170, 260];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = MadarLine.hairline
      ..color = color;
    for (final radius in _radii) {
      canvas.drawCircle(size.center(Offset.zero), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => oldDelegate.color != color;
}
