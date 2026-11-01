import 'package:flutter/material.dart';

import '../../../core/network/generated/models/access.dart';
import '../../../core/network/generated/models/broadcast_entry.dart';
import '../../../core/network/generated/models/broadcast_entry_kind.dart';
import '../../../core/network/generated/models/commentator_ref.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../design/components/commentator_row.dart';
import '../../../design/components/logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/config/media_image.dart';

/// The broadcasters an admin typed in by hand (`kind: custom`), for example «ON Sport 1».
///
/// A `channel` entry repeats a carriage that "where to watch" already lists, so it gets no
/// card. The first card is labelled «يعرض على», the rest «يعرض أيضاً على».
List<BroadcastEntry> manualBroadcasts(MatchDetail match) => [
      for (final entry in match.broadcasts)
        if (entry.kind == BroadcastEntryKind.custom) entry,
    ];

class ManualBroadcasterCards extends StatelessWidget {
  const ManualBroadcasterCards({super.key, required this.entries});

  final List<BroadcastEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s4,
        MadarSpace.s4,
        MadarSpace.s4,
        0,
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: MadarSpace.s2),
            _BroadcasterCard(
              entry: entries[i],
              caption: i == 0 ? l.s3BroadcastOn : l.s3BroadcastAlsoOn,
            ),
          ],
        ],
      ),
    );
  }
}

class _BroadcasterCard extends StatelessWidget {
  const _BroadcasterCard({required this.entry, required this.caption});

  final BroadcastEntry entry;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final access = entry.access;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LogoTile(
                kind: LogoTileKind.channel,
                logo: mediaImage(context, entry.logo),
                fallbackText: entry.label,
                size: MadarSpace.s12,
              ),
              const SizedBox(width: MadarSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                    ),
                    EntityName(
                      entry.label,
                      style: MadarText.heading2.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              if (access != null && access != Access.$unknown) AccessBadge(access: access),
            ],
          ),
          for (final commentator in entry.commentators) ...[
            const SizedBox(height: MadarSpace.s3),
            CommentatorRow(commentator: commentator),
          ],
        ],
      ),
    );
  }
}

/// The stadium, the Egyptian broadcaster and the match's own commentator: each shows only
/// when it has data, and the heading with them.
class MatchInfoSection extends StatelessWidget {
  const MatchInfoSection({super.key, required this.match});

  final MatchDetail match;

  /// True when there is anything for [MatchInfoSection] to show.
  static bool hasContent(MatchDetail match) =>
      _filled(match.stadium) || _filled(match.localBroadcasterEg) || _unlistedCommentator(match) != null;

  static bool _filled(String? value) => value != null && value.trim().isNotEmpty;

  /// The match-level commentator, unless a channel or broadcaster card already shows them.
  static CommentatorRef? _unlistedCommentator(MatchDetail match) {
    final commentator = match.commentator;
    if (commentator == null) return null;
    final listed = {
      for (final carriage in match.carriages) ...carriage.commentators.map((c) => c.id),
      for (final entry in match.broadcasts) ...entry.commentators.map((c) => c.id),
    };
    return listed.contains(commentator.id) ? null : commentator;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final commentator = _unlistedCommentator(match);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s4,
        MadarSpace.s6,
        MadarSpace.s4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.s3MatchInfo, style: MadarText.heading2.copyWith(color: colors.textPrimary)),
          if (_filled(match.stadium)) ...[
            const SizedBox(height: MadarSpace.s3),
            _InfoCard(icon: Icons.place_outlined, label: l.s3Stadium, value: match.stadium!),
          ],
          if (_filled(match.localBroadcasterEg)) ...[
            const SizedBox(height: MadarSpace.s2),
            _InfoCard(
              icon: Icons.tv_outlined,
              label: l.s3LocalBroadcasterEg,
              value: match.localBroadcasterEg!,
            ),
          ],
          if (commentator != null) ...[
            const SizedBox(height: MadarSpace.s2),
            CommentatorRow(commentator: commentator),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: _Card(
        child: Row(
          children: [
            Container(
              width: MadarSpace.s12,
              height: MadarSpace.s12,
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(MadarRadii.md),
              ),
              child: Icon(icon, color: colors.textSecondary),
            ),
            const SizedBox(width: MadarSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MadarText.textCaption.copyWith(color: colors.textTertiary)),
                  EntityName(
                    value,
                    style: MadarText.textStrong.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsets.all(MadarSpace.s3),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(MadarRadii.xl),
        border: Border.all(color: colors.divider, width: MadarLine.hairline),
      ),
      child: child,
    );
  }
}
