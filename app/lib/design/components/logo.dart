import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';

/// Sizes drawn in the design package (Logo README): 28, 40 and 64.
enum BrandMarkSize {
  s28(28),
  m40(40),
  l64(64);

  const BrandMarkSize(this.value);
  final double value;
}

/// Filled ink tile (default), the bare mark for dark wells, or a single-ink mark.
enum BrandMarkTone { filled, bare, mono }

/// The brand mark: a planet inside a volt orbit ring, with a satellite on the ring's upper end.
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
    final mono = tone == BrandMarkTone.mono;
    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: ground,
          borderRadius: BorderRadius.circular(MadarRadii.md),
        ),
        child: CustomPaint(
          painter: MadarMarkPainter(
            ring: mono ? colors.bg : colors.accent,
            // The filled tile and the bare mark always sit on ink, whatever the theme.
            body: mono ? colors.bg : MadarColors.dark.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Paints the mark, `madar-design/design-system/components/Logo/mark.svg`, on its 32-unit grid.
///
/// [orbit] runs the satellite once around the ring, from 0 (its resting place) to 1 (back
/// there), behind the planet on the far half and in front of it on the near half.
class MadarMarkPainter extends CustomPainter {
  const MadarMarkPainter({required this.ring, required this.body, this.orbit})
    : super(repaint: orbit);

  final Color ring;
  final Color body;
  final Animation<double>? orbit;

  static const double _grid = 32;
  static const Offset _ringCenter = Offset(16.07, 15.96);
  static const double _ringRx = 11.84;
  static const double _ringRy = 2.86;
  static const double _ringStroke = 1.66;
  static const double _tilt = -28 * math.pi / 180;

  /// The ring's stroke plus the clear band on each side, where its near half crosses the planet.
  static const double _bandStroke = 3.08;
  static const Offset _planetCenter = Offset(16, 16);
  static const double _planetRadius = 5.69;

  /// The satellite's resting place, in the ring's own tilted frame.
  static const Offset _satelliteRest = Offset(13.19, -2.65);
  static const double _satelliteBody = 2.14;
  static const double _satelliteBodyRadius = 0.5;
  static const Size _panel = Size(1.9, 1.18);
  static const double _panelRadius = 0.2;
  static const double _panelReach = 2.61;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = orbit?.value ?? 0;
    final angle = _restAngle - 2 * math.pi * progress;
    final behindPlanet = math.sin(angle) < 0;
    final bodyPaint = Paint()..color = body;
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: _ringRx * 2,
      height: _ringRy * 2,
    );

    canvas
      ..save()
      ..scale(size.shortestSide / _grid);

    canvas
      ..save()
      ..translate(_ringCenter.dx, _ringCenter.dy)
      ..rotate(_tilt)
      ..drawOval(
        ringRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringStroke
          ..color = ring,
      )
      ..restore();

    if (behindPlanet) _paintSatellite(canvas, angle, progress, bodyPaint);
    _paintPlanet(canvas, ringRect, bodyPaint);
    if (!behindPlanet) _paintSatellite(canvas, angle, progress, bodyPaint);

    canvas.restore();
  }

  /// The planet, with the near half of the ring's band cut out of it.
  void _paintPlanet(Canvas canvas, Rect ringRect, Paint bodyPaint) {
    canvas
      ..saveLayer(
        Rect.fromCircle(center: _planetCenter, radius: _planetRadius),
        Paint(),
      )
      ..drawCircle(_planetCenter, _planetRadius, bodyPaint)
      ..translate(_ringCenter.dx, _ringCenter.dy)
      ..rotate(_tilt)
      ..drawArc(
        ringRect,
        0,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _bandStroke
          ..blendMode = BlendMode.clear,
      )
      ..restore();
  }

  void _paintSatellite(
    Canvas canvas,
    double angle,
    double progress,
    Paint bodyPaint,
  ) {
    // It rides the ring mid-orbit, and lifts to its resting place at both ends.
    final lift = (math.cos(2 * math.pi * progress) + 1) / 2;
    final onRing = Offset(_ringRx * math.cos(angle), _ringRy * math.sin(angle));
    final position = onRing + (_satelliteRest - _restOnRing) * lift;
    canvas
      ..save()
      ..translate(_ringCenter.dx, _ringCenter.dy)
      ..rotate(_tilt)
      ..translate(position.dx, position.dy)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: _satelliteBody,
            height: _satelliteBody,
          ),
          const Radius.circular(_satelliteBodyRadius),
        ),
        bodyPaint,
      );
    for (final side in const [-_panelReach, _panelReach]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(side, 0),
            width: _panel.width,
            height: _panel.height,
          ),
          const Radius.circular(_panelRadius),
        ),
        bodyPaint,
      );
    }
    canvas.restore();
  }

  static final double _restAngle = math.atan2(
    _satelliteRest.dy / _ringRy,
    _satelliteRest.dx / _ringRx,
  );
  static final Offset _restOnRing = Offset(
    _ringRx * math.cos(_restAngle),
    _ringRy * math.sin(_restAngle),
  );

  @override
  bool shouldRepaint(MadarMarkPainter oldDelegate) =>
      oldDelegate.ring != ring ||
      oldDelegate.body != body ||
      oldDelegate.orbit != orbit;
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
          ..strokeWidth = MadarLine.hairline
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
