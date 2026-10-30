import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/digits.dart';
import '../../core/theme/madar_tokens.dart';
import '../../core/network/generated/models/access.dart';
import '../../core/network/generated/models/category.dart';
import '../../core/network/generated/models/channel_carriage.dart';
import '../../core/network/generated/models/frequency.dart';
import '../../core/network/generated/models/polarization.dart';
import '../../l10n/app_localizations.dart';
import 'badges.dart';
import 'frequency_readout.dart';
import 'logo.dart';

/// One channel carrying a match on one satellite: logo tile, name, access badge,
/// satellite and the frequency readout, collapsed. It expands in place.
///
/// The collapsed row is one merged semantics node giving the channel, free or encrypted,
/// the satellite and the frequency.
class CarriageRow extends StatelessWidget {
  const CarriageRow({
    super.key,
    required this.carriage,
    this.expanded = false,
    this.onTap,
    this.onFollow,
    this.onOpenChannel,
    this.onWatchReception,
  });

  final ChannelCarriage carriage;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final VoidCallback? onOpenChannel;

  /// Opens the satellite's reception video; the action shows only when this is given.
  final VoidCallback? onWatchReception;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellite = carriage.satellite;
    final frequency = carriage.frequency;

    return Material(
      color: expanded ? colors.surface2 : colors.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The row is one merged label and one tap target. The actions sit below it, outside
          // `excludeSemantics`, so a screen reader can still reach each of them.
          Semantics(
            label: _semantics(l),
            button: onTap != null,
            expanded: expanded,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: expanded
                    ? const EdgeInsetsDirectional.only(
                        start: MadarSpace.s3,
                        end: MadarSpace.s3,
                        top: MadarSpace.s2,
                      )
                    : const EdgeInsetsDirectional.symmetric(
                        horizontal: MadarSpace.s3,
                        vertical: MadarSpace.s2,
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        LogoTile(
                          kind: LogoTileKind.channel,
                          fallbackText: carriage.name,
                          size: MadarSpace.s5 * 2,
                        ),
                        const SizedBox(width: MadarSpace.s2),
                        Expanded(
                          child: EntityName(
                            carriage.displayName ?? carriage.name,
                            style: MadarText.textStrong.copyWith(color: colors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: MadarSpace.s1),
                        AccessBadge(
                          access: carriage.access ?? Access.$unknown,
                          provider: carriage.provider,
                        ),
                        const SizedBox(width: MadarSpace.s1),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: MadarText.textBody.fontSize,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                    if (!expanded && (satellite != null || frequency != null)) ...[
                      const SizedBox(height: MadarSpace.s1),
                      Row(
                        children: [
                          if (satellite != null) SatelliteBadge(name: satellite.nameAr),
                          const Spacer(),
                          if (frequency != null)
                            FrequencyReadout(
                              mhz: frequency.mhz,
                              polarization: frequency.pol,
                              symbolRate: frequency.sr,
                            )
                          else if (carriage.frequencyNote != null)
                            FrequencyReadout(
                              note: carriage.frequencyNote,
                              state: FrequencyReadoutState.note,
                            ),
                        ],
                      ),
                    ],
                    if (expanded) ...[
                      const SizedBox(height: MadarSpace.s3),
                      _DetailsGrid(carriage: carriage),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: MadarSpace.s3,
                end: MadarSpace.s3,
                top: MadarSpace.s3,
                bottom: MadarSpace.s2,
              ),
              child: Wrap(
                spacing: MadarSpace.s2,
                runSpacing: MadarSpace.s1,
                children: [
                  if (frequency != null)
                    _Action(
                      icon: Icons.copy_outlined,
                      label: l.copyFrequency,
                      onTap: () => _copyFrequency(context, frequency),
                    ),
                  if (onWatchReception != null)
                    _Action(
                      icon: Icons.ondemand_video_outlined,
                      label: l.receptionVideo,
                      onTap: onWatchReception,
                    ),
                  _Action(icon: Icons.notifications_outlined, label: l.follow, onTap: onFollow),
                  if (onOpenChannel != null)
                    _Action(icon: Icons.open_in_new, label: l.details, onTap: onOpenChannel),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Copies `11843 H 27500` and says so (the «تم نسخ التردد» toast).
  Future<void> _copyFrequency(BuildContext context, Frequency frequency) async {
    final message = AppLocalizations.of(context).copiedFrequency;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(
      ClipboardData(
        text: [
          MadarDigits.plain(frequency.mhz),
          frequency.pol.json ?? '',
          MadarDigits.plain(frequency.sr),
        ].join(' '),
      ),
    );
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _semantics(AppLocalizations l) {
    final parts = <String>[carriage.name];
    parts.add(carriage.access == Access.free ? l.free : l.encrypted);
    if (carriage.satellite != null) parts.add(carriage.satellite!.nameAr);
    if (carriage.frequency != null) {
      final f = carriage.frequency!;
      parts.add('${MadarDigits.plain(f.mhz)} ${f.pol.json ?? ''} ${MadarDigits.plain(f.sr)}');
    } else if (carriage.frequencyNote != null) {
      parts.add(carriage.frequencyNote!);
    }
    return parts.join(l.listSeparator);
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.carriage});

  final ChannelCarriage carriage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellite = carriage.satellite;
    final frequency = carriage.frequency;
    final rows = <(String, String)>[
      if (satellite != null)
        (
          l.satellite,
          satellite.orbitalPosition == null
              ? satellite.nameAr
              : '${satellite.nameAr} · ${MadarDigits.decimal(satellite.orbitalPosition!)}',
        ),
      if (frequency != null) (l.frequency, '${MadarDigits.plain(frequency.mhz)} MHz'),
      if (frequency != null) (l.polarization, _polarizationWord(l, frequency.pol)),
      if (frequency != null) (l.symbolRate, MadarDigits.plain(frequency.sr)),
      if (carriage.country != null) (l.country, carriage.country!),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                  ),
                ),
                EntityName(
                  row.$2,
                  style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        if (carriage.category != null)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.details,
                    style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                  ),
                ),
                CategoryBadge(sports: carriage.category == Category.sports),
              ],
            ),
          ),
      ],
    );
  }

  static String _polarizationWord(AppLocalizations l, Polarization pol) => switch (pol) {
        Polarization.h => l.polHorizontal,
        Polarization.v => l.polVertical,
        Polarization.l => l.polLeft,
        Polarization.r => l.polRight,
        _ => '',
      };
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: MadarText.textBody.fontSize, color: colors.accentText),
      label: Text(label, style: MadarText.textCaption.copyWith(color: colors.accentText)),
      style: TextButton.styleFrom(
        minimumSize: const Size(MadarSpace.s12, MadarSpace.s12),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s2),
      ),
    );
  }
}
