import 'package:flutter/material.dart';

import '../../../core/format/digits.dart';
import '../../../core/network/generated/models/access.dart';
import '../../../core/network/generated/models/headline_entry.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../design/components/frequency_readout.dart';
import '../../../design/components/match_row.dart';
import '../../../l10n/app_localizations.dart';

/// One match on S4: the S2 `MatchRow` for the teams and the status, and under it every
/// carriage on the satellites asked for, each with its satellite and its frequency readout
/// (PB S4). The whole row opens the match, and a screen reader hears it as one node.
class SatelliteMatchRow extends StatelessWidget {
  const SatelliteMatchRow({super.key, required this.match, this.onTap, this.now});

  final MatchSummary match;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final carriages = match.broadcast.headline;
    // The carriages below replace the row's own channel line (names only, no readouts).
    final teamsAndStatus = match.copyWith(
      broadcast: match.broadcast.copyWith(headline: const []),
    );
    return MergeSemantics(
      child: Material(
        color: colors.surface1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MatchRow(match: teamsAndStatus, onTap: onTap, now: now),
            for (final carriage in carriages) _CarriageLine(carriage: carriage, onTap: onTap),
            if (carriages.isNotEmpty) const SizedBox(height: MadarSpace.s2),
          ],
        ),
      ),
    );
  }
}

/// A channel on one of the satellites: access glyph, name, satellite, readout.
class _CarriageLine extends StatelessWidget {
  const _CarriageLine({required this.carriage, this.onTap});

  final HeadlineEntry carriage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final free = carriage.access == Access.free;
    final satellite = carriage.satellite;
    final frequency = carriage.frequency;

    return Semantics(
      label: _semantics(l, free),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: MadarSpace.s3,
            vertical: MadarSpace.s1,
          ),
          child: Row(
            children: [
              Icon(
                free ? Icons.lock_open_outlined : Icons.lock_outline,
                size: MadarText.textBody.fontSize,
                color: free ? colors.free : colors.encrypted,
              ),
              const SizedBox(width: MadarSpace.s2),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: EntityName(
                        carriage.name,
                        style: MadarText.textLabel.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (satellite != null) ...[
                      const SizedBox(width: MadarSpace.s2),
                      Flexible(
                        child: Text(
                          satellite.nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (frequency != null) ...[
                const SizedBox(width: MadarSpace.s2),
                FrequencyReadout(
                  mhz: frequency.mhz,
                  polarization: frequency.pol,
                  symbolRate: frequency.sr,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// «ON Sport HD، مجانية، نايل سات، 11977 V 27500».
  String _semantics(AppLocalizations l, bool free) {
    final satellite = carriage.satellite;
    final frequency = carriage.frequency;
    return [
      carriage.name,
      free ? l.free : l.encrypted,
      if (satellite != null) satellite.nameAr,
      if (frequency != null)
        '${MadarDigits.plain(frequency.mhz)} ${frequency.pol.json ?? ''} ${MadarDigits.plain(frequency.sr)}',
    ].join(l.listSeparator);
  }
}
