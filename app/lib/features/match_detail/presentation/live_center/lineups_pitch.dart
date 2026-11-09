import 'package:flutter/material.dart';

import '../../../../core/format/bidi.dart';
import '../../../../core/format/digits.dart';
import '../../../../core/network/generated/models/lineup_player.dart';
import '../../../../core/network/generated/models/match_detail.dart';
import '../../../../core/network/generated/models/match_event_side.dart';
import '../../../../core/theme/madar_line.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/lineup_layout.dart';
import 'lineup_marks.dart';

/// The pitch's height: ten touch targets, about the board's 476.
const double _pitchHeight = MadarLayout.touchMin * 10;

/// Room for a player's circle and name at 1.3×. Slots may overlap, as only their tops are filled.
const double _playerHeight = MadarSpace.s12 * 2;

/// Each group's height on home's half, as a share of the pitch from the top, as on
/// `Match-Lineups.html`. Away's half mirrors it.
const Map<PositionGroup, double> _homeLineY = {
  PositionGroup.goalkeeper: 0.90,
  PositionGroup.defender: 0.80,
  PositionGroup.midfielder: 0.69,
  PositionGroup.forward: 0.58,
};

/// Two elevens on one pitch, home at the bottom as on `Match-Lineups.html` (FR-056). Lines come
/// from the position groups, and the formation is only a label (R16).
class LineupsPitch extends StatelessWidget {
  const LineupsPitch({super.key, required this.match, required this.layout});

  final MatchDetail match;
  final LineupPitch layout;

  String _sideLabel(AppLocalizations l, String team, PitchSide side, MatchEventSide eventSide) {
    String spoken(LineupPlayer player) {
      final marks = marksFor(player.name, eventSide, match.events);
      if (marks.isEmpty) return player.name;
      return '${player.name} (${marks.map((mark) => lineupMarkLabel(l, mark)).join('، ')})';
    }

    final players = [
      for (final line in side.lines) ...line.players.map(spoken),
    ].join('، ');
    final formation = side.formation;
    final title = formation == null ? team : l.lineupPitchSide(team, formation);
    return '$title: $players';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s3,
        vertical: MadarSpace.s3,
      ),
      child: Semantics(
        container: true,
        label: l.lineupPitchLabel(
          _sideLabel(l, match.home.name, layout.home, MatchEventSide.home),
          _sideLabel(l, match.away.name, layout.away, MatchEventSide.away),
        ),
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MadarRadii.xl),
          child: Container(
            height: _pitchHeight,
            decoration: BoxDecoration(
              color: colors.surface1,
              border: Border.all(color: colors.dividerStrong, width: MadarLine.hairline),
              borderRadius: BorderRadius.circular(MadarRadii.xl),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _PitchLines(colors.dividerStrong)),
                    ),
                    ..._players(layout.home, MatchEventSide.home, width),
                    ..._players(layout.away, MatchEventSide.away, width),
                    PositionedDirectional(
                      start: MadarSpace.s3,
                      top: MadarSpace.s2,
                      child: _SideLabel(name: match.away.name, formation: layout.away.formation),
                    ),
                    PositionedDirectional(
                      start: MadarSpace.s3,
                      bottom: MadarSpace.s2,
                      child: _SideLabel(name: match.home.name, formation: layout.home.formation),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _players(PitchSide side, MatchEventSide eventSide, double width) sync* {
    final isHome = eventSide == MatchEventSide.home;
    for (final line in side.lines) {
      final homeY = _homeLineY[line.group]!;
      final y = (isHome ? homeY : 1 - homeY) * _pitchHeight;
      final slot = width / line.length;
      for (final (index, player) in line.players.indexed) {
        yield Positioned(
          left: index * slot,
          width: slot,
          // The circle's centre sits on the line.
          top: y - MadarSpace.s8 / 2,
          height: _playerHeight,
          child: _PlayerMark(
            player: player,
            isHome: isHome,
            marks: marksFor(player.name, eventSide, match.events),
          ),
        );
      }
    }
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.name, required this.formation});

  final String name;
  final String? formation;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final label = formation;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: MadarText.textMicro.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: MadarSpace.s1),
          LtrIsland(label, style: MadarText.textMicro.copyWith(color: colors.textTertiary)),
        ],
      ],
    );
  }
}

class _PlayerMark extends StatelessWidget {
  const _PlayerMark({required this.player, required this.isHome, required this.marks});

  final LineupPlayer player;
  final bool isHome;
  final Set<LineupMark> marks;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final number = player.number;
    // `TeamRef` has no colours, so the two sides are told apart by tokens (R16).
    final ground = isHome ? colors.accentContainer : colors.surface3;
    final foreground = isHome ? colors.accentText : colors.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: MadarSpace.s8,
              height: MadarSpace.s8,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ground, shape: BoxShape.circle),
              child: number == null
                  ? null
                  : Text(
                      MadarDigits.plain(number),
                      style: MadarText.textCaption.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            for (final (index, mark) in marks.indexed)
              Positioned(
                bottom: -MadarSpace.s1,
                right: index * MadarSpace.s3 - MadarSpace.s1,
                child: LineupMarkIcon(mark: mark),
              ),
          ],
        ),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MadarText.textMicro.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The markings: halfway line, centre circle and both boxes.
class _PitchLines extends CustomPainter {
  const _PitchLines(this.color);

  final Color color;

  static const double _centreRadiusShare = 0.1;
  static const double _boxInset = 0.22;
  static const double _boxHeight = 0.15;
  static const double _goalInset = 0.38;
  static const double _goalHeight = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = MadarLine.hairline;
    final middle = size.height / 2;
    canvas
      ..drawLine(Offset(0, middle), Offset(size.width, middle), paint)
      ..drawCircle(Offset(size.width / 2, middle), size.height * _centreRadiusShare, paint);
    for (final (inset, height) in const [(_boxInset, _boxHeight), (_goalInset, _goalHeight)]) {
      final left = size.width * inset;
      final right = size.width - left;
      final depth = size.height * height;
      canvas
        ..drawRect(Rect.fromLTRB(left, 0, right, depth), paint)
        ..drawRect(Rect.fromLTRB(left, size.height - depth, right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PitchLines oldDelegate) => oldDelegate.color != color;
}
