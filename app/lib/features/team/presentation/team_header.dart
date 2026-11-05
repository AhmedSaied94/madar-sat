import 'package:flutter/material.dart';

import '../../../core/network/generated/models/team_detail.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/button.dart';
import '../../../design/components/logo.dart';
import '../../../l10n/app_localizations.dart';

/// S7's header: the crest, the name, the main competition and the stadium, with the follow
/// button under them (§S7).
///
/// The text block reads as one Arabic label: the name, the competition and the stadium. The
/// follow button stays outside it, as its own node.
class TeamHeader extends StatelessWidget {
  const TeamHeader({
    super.key,
    required this.detail,
    required this.logo,
    required this.following,
    required this.onFollow,
  });

  final TeamDetail detail;

  /// The crest's image, or null for the shield fallback (`TeamCrest`).
  final ImageProvider? logo;
  final bool following;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final competition = detail.primaryCompetition?.name;
    final stadium = detail.stadium;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s4,
        MadarSpace.s4,
        MadarSpace.s4,
        MadarSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: [detail.name, ?competition, ?stadium].join(l.listSeparator),
            excludeSemantics: true,
            child: Row(
              children: [
                TeamCrest(name: detail.name, logo: logo, size: MadarSpace.s12 + MadarSpace.s6),
                const SizedBox(width: MadarSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        detail.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MadarText.heading1.copyWith(color: colors.textPrimary),
                      ),
                      if (competition != null) ...[
                        const SizedBox(height: MadarSpace.s1),
                        _IconLine(icon: Icons.emoji_events_outlined, text: competition),
                      ],
                      if (stadium != null) ...[
                        const SizedBox(height: MadarSpace.s1),
                        _IconLine(icon: Icons.stadium_outlined, text: stadium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MadarSpace.s4),
          MadarButton(
            label: following ? l.s7FollowingTeam : l.s7FollowTeam,
            icon: following ? Icons.star : Icons.star_border,
            variant: following ? MadarButtonVariant.secondary : MadarButtonVariant.primary,
            expanded: true,
            onPressed: onFollow,
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Row(
      children: [
        Icon(icon, size: MadarText.textCaption.fontSize, color: colors.textTertiary),
        const SizedBox(width: MadarSpace.s1),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MadarText.textCaption.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
