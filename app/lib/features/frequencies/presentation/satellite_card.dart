import 'package:flutter/material.dart';

import '../../../core/format/bidi.dart';
import '../../../core/format/digits.dart';
import '../../../core/network/generated/models/satellite.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../l10n/app_localizations.dart';
import 'position_well.dart';

/// One satellite on S5.1: its position well, Arabic name, English name with the channel count,
/// and a marker when it is one of mine. The whole card opens the satellite.
class SatelliteCard extends StatelessWidget {
  const SatelliteCard({
    super.key,
    required this.satellite,
    required this.isMine,
    this.onTap,
  });

  final Satellite satellite;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final count = l.s5ChannelCount(MadarDigits.plain(satellite.channelCount));

    return Semantics(
      label: [
        satellite.nameAr,
        satellite.nameEn,
        count,
        if (isMine) l.s5MineMarker,
      ].join(l.listSeparator),
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface1,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: MadarSpace.s3,
              vertical: MadarSpace.s3,
            ),
            child: Row(
              children: [
                PositionWell(position: satellite.orbitalPosition),
                const SizedBox(width: MadarSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              satellite.nameAr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MadarText.textStrong.copyWith(color: colors.textPrimary),
                            ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: MadarSpace.s2),
                            SatelliteBadge(name: l.s5MineMarker),
                          ],
                        ],
                      ),
                      const SizedBox(height: MadarSpace.s1),
                      Row(
                        children: [
                          Flexible(
                            child: LtrIsland(
                              satellite.nameEn,
                              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                            ),
                          ),
                          const SizedBox(width: MadarSpace.s1),
                          Text(
                            '·',
                            style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                          ),
                          const SizedBox(width: MadarSpace.s1),
                          Text(
                            count,
                            maxLines: 1,
                            style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MadarSpace.s2),
                // Points left in RTL: the way forward.
                Icon(Icons.chevron_right, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
