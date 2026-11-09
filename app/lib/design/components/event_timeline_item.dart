import 'package:flutter/material.dart';

import '../../core/format/bidi.dart';
import '../../core/format/digits.dart';
import '../../core/network/generated/models/match_event.dart';
import '../../core/network/generated/models/match_event_side.dart';
import '../../core/network/generated/models/match_event_type.dart';
import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';

/// One event on the match timeline (EventTimeline README): home's cell on the right, the minute
/// on the spine in mono and LTR, away's cell on the left.
///
/// Goals and penalties use `accent-container` tiles, red cards `error` and misses
/// `text-tertiary`, each with its own glyph, so meaning never rests on colour alone. The row is
/// one merged Arabic label for a screen reader (PB §13.8).
class EventTimelineItem extends StatelessWidget {
  const EventTimelineItem({
    super.key,
    required this.event,
    required this.teamName,
    this.runningScore,
  });

  final MatchEvent event;

  /// The team the event is credited to, for the spoken label.
  final String teamName;

  /// The score after this goal, shown only when the known goals add up (FR-053).
  final ({int home, int away})? runningScore;

  bool get _isHome => event.side == MatchEventSide.home;

  String _typeLabel(AppLocalizations l) {
    final score = runningScore;
    return switch (event.type) {
      MatchEventType.goal when score != null => l.tlGoalWithScore(
          '${MadarDigits.plain(score.home)} – ${MadarDigits.plain(score.away)}',
        ),
      MatchEventType.goal => l.tlGoal,
      MatchEventType.ownGoal => l.tlOwnGoal,
      MatchEventType.penalty => l.tlPenalty,
      MatchEventType.missedPenalty => l.tlMissedPenalty,
      MatchEventType.redCard => l.tlRedCard,
      MatchEventType.$unknown => '',
    };
  }

  String _semantics(AppLocalizations l) {
    final minute = _bareMinute(event.minute);
    return [
      _typeLabel(l),
      if (event.player != null) event.player!,
      teamName,
      l.tlMinuteLabel(minute),
    ].join('، ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cell = _EventCell(event: event, typeLabel: _typeLabel(l), alignEnd: !_isHome);
    return Semantics(
      container: true,
      label: _semantics(l),
      excludeSemantics: true,
      child: TimelineSpine(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
          child: Row(
            children: [
              Expanded(child: _isHome ? cell : const SizedBox.shrink()),
              // At least the board's width, and wider when a stoppage minute at 1.3× needs it:
              // the minute is never cut. The two equal cells keep it on the spine.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: MadarSpace.s12),
                child: Center(
                  widthFactor: 1,
                  child: _MinutePill(minute: _bareMinute(event.minute)),
                ),
              ),
              Expanded(child: _isHome ? const SizedBox.shrink() : cell),
            ],
          ),
        ),
      ),
    );
  }
}

/// A period marker on the spine: «الشوط الثاني».
class TimelineMarkerRow extends StatelessWidget {
  const TimelineMarkerRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return TimelineSpine(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s2),
        child: Center(
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: MadarSpace.s3,
              vertical: MadarSpace.s1,
            ),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(MadarRadii.pill),
              border: Border.all(color: colors.divider, width: MadarLine.hairline),
            ),
            child: Text(
              label,
              style: MadarText.textCaption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The vertical line behind a row.
class TimelineSpine extends StatelessWidget {
  const TimelineSpine({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: MadarLine.hairline,
                height: double.infinity,
                child: ColoredBox(color: context.madarColors.dividerStrong),
              ),
            ),
          ),
          child,
        ],
      );
}

/// `45+2`, whether the API sent `45+2` or `45+2′`.
String _bareMinute(String minute) => minute.replaceAll('′', '').trim();

class _MinutePill extends StatelessWidget {
  const _MinutePill({required this.minute});

  final String minute;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      constraints: const BoxConstraints(minHeight: MadarSpace.s6),
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s1),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(MadarRadii.pill),
        border: Border.all(color: colors.dividerStrong, width: MadarLine.hairline),
      ),
      child: LtrIsland(
        '$minute′',
        overflow: TextOverflow.visible,
        style: MadarText.monoCode.copyWith(color: colors.textPrimary),
      ),
    );
  }
}

class _EventCell extends StatelessWidget {
  const _EventCell({required this.event, required this.typeLabel, required this.alignEnd});

  final MatchEvent event;
  final String typeLabel;

  /// Away's cell mirrors home's, so the tile sits on the outer edge either way.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final player = event.player;
    final text = Flexible(
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (player != null)
            Text(
              player,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: MadarText.textStrong.copyWith(color: colors.textPrimary),
            ),
          Text(
            typeLabel,
            style: MadarText.textCaption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
    final tile = _EventTile(type: event.type);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignEnd
            ? [text, const SizedBox(width: MadarSpace.s2), tile]
            : [tile, const SizedBox(width: MadarSpace.s2), text],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.type});

  final MatchEventType type;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final (icon, foreground, background) = switch (type) {
      MatchEventType.redCard => (Icons.rectangle, colors.error, colors.surface2),
      MatchEventType.missedPenalty => (Icons.block, colors.textTertiary, colors.surface2),
      _ => (Icons.sports_soccer, colors.accentText, colors.accentContainer),
    };
    return Container(
      width: MadarSpace.s8,
      height: MadarSpace.s8,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MadarRadii.md),
      ),
      child: Icon(icon, size: MadarText.textBody.fontSize, color: foreground),
    );
  }
}
