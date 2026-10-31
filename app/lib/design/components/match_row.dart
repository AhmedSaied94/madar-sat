import 'package:flutter/material.dart';

import '../../core/format/bidi.dart';
import '../../core/format/digits.dart';
import '../../core/format/time.dart';
import '../../core/theme/madar_tokens.dart';
import '../../core/network/generated/models/match_summary.dart';
import '../../core/network/generated/models/sport.dart';
import '../../core/network/generated/models/status.dart';
import '../../l10n/app_localizations.dart';
import 'logo.dart';
import 'status_block.dart';

/// One match in a list: home team, status, away team, and the channel line that answers
/// where it airs (up to two channels, free first).
///
/// The whole row is one target, and one merged semantics node reads
/// «الأهلي ضد الزمالك، مباشر، الدقيقة 67، النتيجة 1 مقابل 0، على أون سبورت 1».
class MatchRow extends StatelessWidget {
  const MatchRow({
    super.key,
    required this.match,
    this.onTap,
    this.onLongPress,
    this.use24h = false,
    this.followed = false,
    this.reminder = false,
    this.now,
  });

  final MatchSummary match;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool use24h;
  final bool followed;
  final bool reminder;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final individual = match.sport == Sport.tennis;
    final headline = match.broadcast.headline;
    final firstChannel = headline.isEmpty ? null : headline.first.name;

    return Semantics(
      label: _semantics(l, firstChannel),
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface1,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MadarSpace.s12 + MadarSpace.s6,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MadarSpace.s3,
                vertical: MadarSpace.s2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Team(
                          name: match.home.name,
                          logo: match.home.logo,
                          leading: true,
                          followed: followed,
                          reminder: reminder,
                          individual: individual,
                          alignEnd: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: MadarSpace.s2,
                        ),
                        child: SizedBox(
                          width: MadarSpace.s12 + MadarSpace.s8,
                          child: StatusBlock(
                            status: match.status,
                            kickoff: match.kickoffAt,
                            score: match.score,
                            minute: match.minute,
                            estimated: match.estimated,
                            timeTbd: match.timeTbd,
                            use24h: use24h,
                            now: now,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Team(
                          name: match.away.name,
                          logo: match.away.logo,
                          leading: false,
                          individual: individual,
                          alignEnd: false,
                        ),
                      ),
                    ],
                  ),
                  if (headline.isNotEmpty) ...[
                    const SizedBox(height: MadarSpace.s1),
                    _ChannelLine(
                      names: headline.map((h) => h.name).toList(growable: false),
                      extra: match.broadcast.channelCount - headline.length,
                      hasFree: match.broadcast.hasFree,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semantics(AppLocalizations l, String? channel) {
    final parts = <String>[l.vs(match.away.name, match.home.name)];
    switch (match.status) {
      case Status.scheduled:
        final time = MadarTime.kickoff(
          match.kickoffAt,
          use24h: use24h,
          am: l.amMarker,
          pm: l.pmMarker,
        );
        parts.add(match.timeTbd || time == null ? l.timeTbd : time);
      case Status.live:
        parts.add(l.live);
        if (!match.estimated) {
          if (match.minute != null) {
            parts.add(l.minuteSemantics(match.minute!));
          }
          if (match.score != null) {
            parts.add(
              l.scoreSemantics(
                MadarDigits.plain(match.score!.away),
                MadarDigits.plain(match.score!.home),
              ),
            );
          }
        }
      case Status.halftime:
        parts.add(l.halftime);
        if (match.score != null) {
          parts.add(
            l.scoreSemantics(
              MadarDigits.plain(match.score!.away),
              MadarDigits.plain(match.score!.home),
            ),
          );
        }
      case Status.finished:
        parts.add(l.finished);
        if (match.score != null) {
          parts.add(
            l.scoreSemantics(
              MadarDigits.plain(match.score!.away),
              MadarDigits.plain(match.score!.home),
            ),
          );
        }
      case Status.extraTime:
        parts.add(l.extraTime);
      case Status.penalties:
        parts.add(l.penalties);
      case Status.postponed:
        parts.add(l.postponed);
      case Status.cancelled:
        parts.add(l.cancelled);
      case Status.abandoned:
        parts.add(l.abandoned);
      case Status.$unknown:
        break;
    }
    if (channel != null) parts.add(l.channelOn(channel));
    return parts.join(l.listSeparator);
  }
}

/// The sport names the row treats as individual (no crests).
class _Team extends StatelessWidget {
  const _Team({
    required this.name,
    required this.logo,
    required this.leading,
    required this.individual,
    required this.alignEnd,
    this.followed = false,
    this.reminder = false,
  });

  final String name;
  final String? logo;
  final bool leading;
  final bool individual;
  final bool alignEnd;
  final bool followed;
  final bool reminder;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final crest = individual
        ? null
        : TeamCrest(
            name: name,
            logo: logo == null ? null : NetworkImage(logo!),
            size: MadarSpace.s6,
          );
    final nameWidget = Flexible(
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: MadarText.textLabel.copyWith(color: colors.textPrimary),
      ),
    );
    final children = <Widget>[
      if (leading && crest != null) crest,
      if (leading && crest != null) const SizedBox(width: MadarSpace.s2),
      nameWidget,
      if (!leading && crest != null) const SizedBox(width: MadarSpace.s2),
      if (!leading && crest != null) crest,
      if (followed) ...[
        const SizedBox(width: MadarSpace.s1),
        Icon(Icons.star, size: MadarText.textMicro.fontSize, color: colors.accentText),
      ],
      if (reminder) ...[
        const SizedBox(width: MadarSpace.s1),
        Icon(
          Icons.notifications_active_outlined,
          size: MadarText.textMicro.fontSize,
          color: colors.accentText,
        ),
      ],
    ];
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: children,
    );
  }
}

class _ChannelLine extends StatelessWidget {
  const _ChannelLine({
    required this.names,
    required this.extra,
    required this.hasFree,
  });

  final List<String> names;
  final int extra;
  final bool hasFree;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.tv_outlined, size: MadarText.textMicro.fontSize, color: colors.textTertiary),
        const SizedBox(width: MadarSpace.s1),
        Flexible(
          child: LtrIsland(
            names.take(2).join(' · '),
            style: MadarText.textCaption.copyWith(color: colors.textSecondary),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: MadarSpace.s1),
          // A count with a sign is an LTR island: in RTL text the `+` would land after the digits.
          LtrIsland(
            l.channelsMore(MadarDigits.plain(extra)),
            style: MadarText.textMicro.copyWith(color: colors.textTertiary),
          ),
        ],
        if (hasFree) ...[
          const SizedBox(width: MadarSpace.s2),
          Icon(Icons.lock_open_outlined, size: MadarText.textMicro.fontSize, color: colors.free),
          const SizedBox(width: MadarSpace.s1),
          Text(l.free, style: MadarText.textMicro.copyWith(color: colors.free)),
        ],
      ],
    );
  }
}
