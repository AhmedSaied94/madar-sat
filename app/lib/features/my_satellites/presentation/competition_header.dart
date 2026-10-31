import 'package:flutter/material.dart';

import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/logo.dart';
import '../domain/competition_groups.dart';

/// The heading of one competition's group: its logo, its name and, when the matches share
/// it, the round («الجولة 8»).
class CompetitionHeader extends StatelessWidget {
  const CompetitionHeader({super.key, required this.group});

  final CompetitionGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final competition = group.competition;
    final logo = competition.logo;
    final stage = group.stage;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s4,
          MadarSpace.s4,
          MadarSpace.s4,
          MadarSpace.s2,
        ),
        child: Row(
          children: [
            LogoTile(
              kind: LogoTileKind.competition,
              logo: logo == null ? null : NetworkImage(logo),
              size: MadarSpace.s8,
            ),
            const SizedBox(width: MadarSpace.s2),
            Expanded(
              child: Text(
                competition.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MadarText.heading2.copyWith(color: colors.textPrimary),
              ),
            ),
            if (stage != null) ...[
              const SizedBox(width: MadarSpace.s2),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s2,
                  vertical: MadarSpace.s1,
                ),
                decoration: BoxDecoration(
                  color: colors.surface3,
                  borderRadius: BorderRadius.circular(MadarRadii.sm),
                ),
                child: Text(
                  stage,
                  maxLines: 1,
                  style: MadarText.textMicro.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
