import 'package:flutter/material.dart';

import '../../core/theme/madar_tokens.dart';

/// Sizes drawn in the design package (Logo README): 28, 40 and 64.
enum BrandMarkSize {
  s28(28),
  m40(40),
  l64(64);

  const BrandMarkSize(this.value);
  final double value;
}

/// Filled ink tile (default), bare orbit ring, or a single-ink mark on busy grounds.
enum BrandMarkTone { filled, bare, mono }

/// The placeholder brand mark: an ink tile with a volt orbit ring and a satellite dot.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = BrandMarkSize.m40,
    this.tone = BrandMarkTone.filled,
  });

  final BrandMarkSize size;
  final BrandMarkTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final side = size.value;
    final ground = switch (tone) {
      BrandMarkTone.filled => colors.onAccent,
      BrandMarkTone.bare => null,
      BrandMarkTone.mono => colors.textPrimary,
    };
    final ring = switch (tone) {
      BrandMarkTone.filled => colors.accent,
      BrandMarkTone.bare => colors.accent,
      BrandMarkTone.mono => colors.bg,
    };
    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: ground,
          borderRadius: BorderRadius.circular(MadarRadii.md),
        ),
        child: CustomPaint(
          painter: _OrbitMarkPainter(ring: ring, dot: ring, tone: tone),
        ),
      ),
    );
  }
}

class _OrbitMarkPainter extends CustomPainter {
  const _OrbitMarkPainter({required this.ring, required this.dot, required this.tone});

  final Color ring;
  final Color dot;
  final BrandMarkTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.28;
    final stroke = size.shortestSide * 0.09;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = ring;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2.6,
        height: radius * 1.5,
      ),
      paint,
    );
    final dotPaint = Paint()..color = dot;
    canvas.drawCircle(
      center + Offset(radius * 1.05, -radius * 0.28),
      stroke * 0.75,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(_OrbitMarkPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.dot != dot || oldDelegate.tone != tone;
}

/// The orbit mark with the «مدار» wordmark beside it (Changa 800).
class MadarWordmark extends StatelessWidget {
  const MadarWordmark({super.key, this.wordmark = 'مدار', this.size = BrandMarkSize.m40});

  final String wordmark;
  final BrandMarkSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        const SizedBox(width: MadarSpace.s2),
        Text(
          wordmark,
          style: MadarText.heading1.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

/// The neutral frame for a team crest, with the first-letter shield as its fallback.
class TeamCrest extends StatelessWidget {
  const TeamCrest({super.key, this.name, this.logo, this.size = MadarSpace.s12});

  final String? name;
  final ImageProvider? logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final first = (name ?? '').trim().characters.isEmpty
        ? ''
        : (name ?? '').trim().characters.first;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(MadarRadii.md),
          border: Border.all(color: colors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MadarSpace.s1),
          child: logo != null
              ? Image(image: logo!, fit: BoxFit.contain)
              : CustomPaint(
                  painter: _ShieldPainter(
                    ground: colors.surface3,
                    edge: colors.accentText,
                    ink: colors.textPrimary,
                    letter: first,
                    textStyle: MadarText.textMicro,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter({
    required this.ground,
    required this.edge,
    required this.ink,
    required this.letter,
    required this.textStyle,
  });

  final Color ground;
  final Color edge;
  final Color ink;
  final String letter;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.22)
      ..lineTo(size.width, size.height * 0.62)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width * 0.5,
        size.height,
      )
      ..quadraticBezierTo(0, size.height, 0, size.height * 0.62)
      ..lineTo(0, size.height * 0.22)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = ground)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = edge,
      );
    if (letter.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: letter,
        style: textStyle.copyWith(color: ink),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) =>
      oldDelegate.ground != ground ||
      oldDelegate.edge != edge ||
      oldDelegate.ink != ink ||
      oldDelegate.letter != letter;
}

/// What an entity logo frame falls back to when the entity has no asset.
enum LogoTileKind { team, competition, channel, satellite, commentator }

/// A third-party logo in the same neutral tile, or the documented entity fallback.
class LogoTile extends StatelessWidget {
  const LogoTile({
    super.key,
    required this.kind,
    this.logo,
    this.fallbackText,
    this.size = MadarSpace.s12,
  });

  final LogoTileKind kind;
  final ImageProvider? logo;
  final String? fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final glyph = switch (kind) {
      LogoTileKind.team => null,
      LogoTileKind.competition => Icons.emoji_events_outlined,
      LogoTileKind.channel => Icons.tv_outlined,
      LogoTileKind.satellite => Icons.satellite_alt_outlined,
      LogoTileKind.commentator => Icons.person_outline,
    };
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(MadarRadii.md),
          border: Border.all(color: colors.divider),
        ),
        child: logo != null
            ? Padding(
                padding: const EdgeInsets.all(MadarSpace.s1),
                child: Image(image: logo!, fit: BoxFit.contain),
              )
            : Center(
                child: glyph != null
                    ? Icon(glyph, size: size * 0.45, color: colors.textSecondary)
                    : Text(
                        _initials(fallbackText),
                        style: MadarText.textMicro.copyWith(color: colors.textSecondary),
                      ),
              ),
      ),
    );
  }

  static String _initials(String? text) {
    final value = (text ?? '').trim();
    if (value.isEmpty) return '';
    final latin = RegExp('[A-Za-z]').allMatches(value).map((m) => m[0]!).take(3);
    if (latin.isNotEmpty) return latin.join().toUpperCase();
    return value.characters.take(2).toString();
  }
}
