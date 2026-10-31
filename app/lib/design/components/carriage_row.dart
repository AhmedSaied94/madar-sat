import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/bidi.dart';
import '../../core/format/digits.dart';
import '../../core/network/generated/models/access.dart';
import '../../core/network/generated/models/category.dart';
import '../../core/network/generated/models/channel_carriage.dart';
import '../../core/network/generated/models/frequency.dart';
import '../../core/network/generated/models/polarization.dart';
import '../../core/network/generated/models/satellite_ref.dart';
import '../../core/theme/madar_tokens.dart';
import '../../features/frequencies/domain/orbital_position.dart';
import '../../l10n/app_localizations.dart';
import 'badges.dart';
import 'frequency_readout.dart';
import 'logo.dart';

/// One channel carrying a match on one satellite: logo tile, name, access badge,
/// satellite and the frequency readout, collapsed. It expands in place.
///
/// The collapsed row is one merged semantics node giving the channel, free or encrypted,
/// the satellite and the frequency.
class CarriageRow extends StatefulWidget {
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

  /// The follow action; it shows only once follows exist (D3).
  final VoidCallback? onFollow;
  final VoidCallback? onOpenChannel;

  /// Opens the satellite's reception video; the action shows only when this is given.
  final VoidCallback? onWatchReception;

  @override
  State<CarriageRow> createState() => _CarriageRowState();
}

class _CarriageRowState extends State<CarriageRow> {
  /// The readout's copied state: the `success` outline, until the toast is gone.
  static const Duration _copiedFor = Duration(seconds: 2);

  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final carriage = widget.carriage;
    final expanded = widget.expanded;
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
            button: widget.onTap != null,
            expanded: expanded,
            onTap: widget.onTap,
            excludeSemantics: true,
            child: InkWell(
              onTap: widget.onTap,
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
                    // The readout stays on the row open or closed: it is the answer the
                    // screen exists for, and tapping it copies (CarriageRow README).
                    if (satellite != null || frequency != null || carriage.frequencyNote != null) ...[
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
                              state: _copied
                                  ? FrequencyReadoutState.good
                                  : FrequencyReadoutState.ok,
                              onTap: () => _copyFrequency(context, frequency),
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
                  if (widget.onWatchReception != null)
                    _Action(
                      icon: Icons.ondemand_video_outlined,
                      label: l.receptionVideo,
                      onTap: widget.onWatchReception,
                    ),
                  // A follow action that does nothing would be a lie (constitution I): it
                  // appears only when a caller can actually follow the channel.
                  if (widget.onFollow != null)
                    _Action(
                      icon: Icons.notifications_outlined,
                      label: l.follow,
                      onTap: widget.onFollow,
                    ),
                  if (widget.onOpenChannel != null)
                    _Action(
                      icon: Icons.open_in_new,
                      label: l.details,
                      onTap: widget.onOpenChannel,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Copies `11843 H 27500`, says so, and outlines the readout in `success` for a moment.
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
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(_copiedFor, () {
      if (mounted) setState(() => _copied = false);
    });
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _semantics(AppLocalizations l) {
    final carriage = widget.carriage;
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

/// The expanded details: the satellite with its English name and, when the name leaves it
/// out, its orbital position; the tuning in words, access with its provider and package, and
/// the category. Latin names, frequencies and positions are LTR islands inside the Arabic
/// labels (constitution III).
class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.carriage});

  final ChannelCarriage carriage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellite = carriage.satellite;
    final frequency = carriage.frequency;
    final valueStyle = MadarText.textLabel.copyWith(color: colors.textPrimary);
    final latinStyle = valueStyle.copyWith(color: colors.textSecondary);

    return Column(
      children: [
        if (satellite != null)
          _DetailRow(
            label: l.satellite,
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MadarSpace.s1,
              runSpacing: MadarSpace.s1,
              children: [
                Text(satellite.nameAr, style: valueStyle),
                LtrIsland(satellite.nameEn, style: latinStyle),
                if (_extraPosition(satellite) case final degrees?)
                  LtrIsland(degrees, style: latinStyle),
              ],
            ),
          ),
        if (frequency != null)
          _DetailRow(
            label: l.frequency,
            // The number and its Latin unit are one LTR island: in the RTL row a plain
            // `Text` draws «MHz 11843», the unit first (M-R2-1).
            child: LtrIsland('${MadarDigits.plain(frequency.mhz)} MHz', style: valueStyle),
          ),
        if (frequency != null)
          _DetailRow(
            label: l.polarization,
            child: Text(_polarizationWord(l, frequency.pol), style: valueStyle),
          ),
        if (frequency != null)
          _DetailRow(
            label: l.symbolRate,
            child: Text(MadarDigits.plain(frequency.sr), style: valueStyle),
          ),
        _DetailRow(
          label: l.access,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MadarSpace.s1,
            runSpacing: MadarSpace.s1,
            children: [
              AccessBadge(
                access: carriage.access ?? Access.$unknown,
                provider: carriage.provider,
              ),
              if (carriage.package case final package?) EntityName(package, style: latinStyle),
            ],
          ),
        ),
        if (carriage.category != null)
          _DetailRow(
            label: l.category,
            child: CategoryBadge(sports: carriage.category == Category.sports),
          ),
        if (carriage.country != null)
          _DetailRow(label: l.country, child: Text(carriage.country!, style: valueStyle)),
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

  /// The orbital position this row still has to draw, if any.
  ///
  /// `name_en` already carries it ("Nilesat 7.0W", "Hotbird 13.0E"), as the `Match-Channels`
  /// board draws it, so the row names it once. It is added, with its degree sign, only when
  /// the English name leaves it out (M-R2-8).
  static String? _extraPosition(SatelliteRef satellite) {
    final label = OrbitalPosition.label(satellite.orbitalPosition);
    if (label == null || satellite.nameEn.contains(label)) return null;
    return OrbitalPosition.degrees(satellite.orbitalPosition);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
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
