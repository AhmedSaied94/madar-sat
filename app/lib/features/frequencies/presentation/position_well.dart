import 'package:flutter/material.dart';

import '../../../core/format/bidi.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../domain/orbital_position.dart';

/// A satellite's orbital position on the dark readout well: `7.0W`, with a small track that
/// puts the dot where the satellite sits on the arc. Like the frequency readout it stays dark
/// and left-to-right in both themes (constitution IV), and the position is an LTR island.
///
/// [large] is the S5.2 header form, `7.0°W`, without the track.
class PositionWell extends StatelessWidget {
  const PositionWell({super.key, required this.position, this.large = false});

  final num? position;
  final bool large;

  /// The arc runs about 60° either side of the Greenwich meridian across the track: the
  /// design puts 30°W at 28 % and 26°E at 70 %, which is a slope of 0.75 around the middle.
  static const double _arcSlope = 0.75;
  static const double _arcHalfWidth = 50;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final label = large ? OrbitalPosition.degrees(position) : OrbitalPosition.label(position);
    final style = (large ? MadarText.readoutLg : MadarText.readout).copyWith(
      color: colors.readout,
      shadows: context.madarShadows.readoutGlow,
    );

    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(
          minWidth: large ? MadarSpace.s12 + MadarSpace.s8 : MadarSpace.s12 + MadarSpace.s2,
          minHeight: MadarSpace.s12 + MadarSpace.s2,
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s2,
          vertical: MadarSpace.s2,
        ),
        decoration: BoxDecoration(
          color: colors.readoutBg,
          borderRadius: BorderRadius.circular(large ? MadarRadii.lg : MadarRadii.md),
          border: Border.all(color: colors.readoutLine),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label == null)
              Icon(Icons.satellite_alt_outlined, size: style.fontSize, color: colors.readoutDim)
            else
              LtrIsland(label, style: style),
            if (!large && label != null) ...[
              const SizedBox(height: MadarSpace.s1),
              _Track(fraction: _fraction(position!)),
            ],
          ],
        ),
      ),
    );
  }

  /// -1 (left end) to 1 (right end); east is to the right whatever the text direction.
  static double _fraction(num position) =>
      ((position * _arcSlope) / _arcHalfWidth).clamp(-1.0, 1.0);
}

class _Track extends StatelessWidget {
  const _Track({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return SizedBox(
      width: MadarSpace.s8,
      height: MadarSpace.s1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(height: MadarLine.hairline, color: colors.readoutLine),
          Align(
            alignment: Alignment(fraction, 0),
            child: Container(
              width: MadarSpace.s1,
              height: MadarSpace.s1,
              decoration: BoxDecoration(color: colors.readout, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
