import 'package:flutter/material.dart';

import '../../../../core/format/bidi.dart';
import '../../../../core/format/digits.dart';
import '../../../../core/network/generated/models/lineup_player.dart';
import '../../../../core/network/generated/models/match_detail.dart';
import '../../../../core/network/generated/models/match_event_side.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/lineup_layout.dart';
import 'lineup_marks.dart';

sealed class _Entry {
  const _Entry();
}

final class _Team extends _Entry {
  const _Team(this.name, this.formation);

  final String name;
  final String? formation;
}

final class _Heading extends _Entry {
  const _Heading(this.text);

  final String text;
}

final class _Player extends _Entry {
  const _Player(this.player, this.side);

  final LineupPlayer player;
  final MatchEventSide side;
}

/// Two lists, for lineups with no usable positions (FR-056, R16). No board draws them, so they
/// follow S3's row style: each side's starters, then its substitutes.
class LineupsListsSliver extends StatelessWidget {
  const LineupsListsSliver({super.key, required this.match, required this.layout});

  final MatchDetail match;
  final LineupLists layout;

  List<_Entry> _entries(AppLocalizations l) => [
        ..._side(l, match.home.name, layout.home, MatchEventSide.home),
        ..._side(l, match.away.name, layout.away, MatchEventSide.away),
      ];

  static List<_Entry> _side(
    AppLocalizations l,
    String team,
    ListSide? side,
    MatchEventSide eventSide,
  ) {
    if (side == null) return const [];
    return [
      _Team(team, side.formation),
      if (side.starters.isNotEmpty) ...[
        _Heading(l.lineupStarters),
        for (final player in side.starters) _Player(player, eventSide),
      ],
      if (side.substitutes.isNotEmpty) ...[
        _Heading(l.lineupSubstitutes),
        for (final player in side.substitutes) _Player(player, eventSide),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries(AppLocalizations.of(context));
    return SliverPadding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s2,
      ),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) => switch (entries[index]) {
          _Team(:final name, :final formation) => _TeamRow(name: name, formation: formation),
          _Heading(:final text) => _HeadingRow(text: text),
          _Player(:final player, :final side) => _PlayerRow(
              player: player,
              marks: marksFor(player.name, side, match.events),
            ),
        },
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.name, required this.formation});

  final String name;
  final String? formation;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final label = formation;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: MadarSpace.s3, bottom: MadarSpace.s1),
      child: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MadarText.textStrong.copyWith(color: colors.textPrimary),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: MadarSpace.s2),
            LtrIsland(label, style: MadarText.monoCode.copyWith(color: colors.textTertiary)),
          ],
        ],
      ),
    );
  }
}

class _HeadingRow extends StatelessWidget {
  const _HeadingRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
        child: Text(
          text,
          style: MadarText.textCaption.copyWith(
            color: context.madarColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.marks});

  final LineupPlayer player;
  final Set<LineupMark> marks;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final l = AppLocalizations.of(context);
    final number = player.number;
    return Semantics(
      container: true,
      label: [
        player.name,
        if (number != null) MadarDigits.plain(number),
        for (final mark in marks) lineupMarkLabel(l, mark),
      ].join('، '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
        child: Row(
          children: [
            SizedBox(
              width: MadarSpace.s8,
              child: number == null
                  ? null
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LtrIsland(
                        MadarDigits.plain(number),
                        style: MadarText.monoCode.copyWith(color: colors.textTertiary),
                      ),
                    ),
            ),
            Expanded(
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MadarText.textBody.copyWith(color: colors.textPrimary),
              ),
            ),
            for (final mark in marks) ...[
              const SizedBox(width: MadarSpace.s1),
              LineupMarkIcon(mark: mark),
            ],
          ],
        ),
      ),
    );
  }
}
