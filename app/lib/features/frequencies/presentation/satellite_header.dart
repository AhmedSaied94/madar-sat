import 'package:flutter/material.dart';

import '../../../core/format/bidi.dart';
import '../../../core/format/digits.dart';
import '../../../core/network/generated/models/frequency.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/frequency_readout.dart';
import '../../../l10n/app_localizations.dart';
import 'position_well.dart';

/// The top of S5.2: the position well, the Arabic name, and the English name with the
/// channel count.
class SatelliteHeader extends StatelessWidget {
  const SatelliteHeader({
    super.key,
    required this.nameAr,
    required this.nameEn,
    required this.position,
    required this.channelCount,
  });

  final String nameAr;
  final String nameEn;
  final num? position;
  final int? channelCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final caption = MadarText.textCaption.copyWith(color: colors.textTertiary);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s3,
      ),
      child: Row(
        children: [
          PositionWell(position: position, large: true),
          const SizedBox(width: MadarSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    nameAr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MadarText.heading1.copyWith(color: colors.textPrimary),
                  ),
                ),
                Row(
                  children: [
                    Flexible(child: LtrIsland(nameEn, style: caption)),
                    if (channelCount != null) ...[
                      const SizedBox(width: MadarSpace.s1),
                      Text('·', style: caption),
                      const SizedBox(width: MadarSpace.s1),
                      Text(l.s5ChannelCount(MadarDigits.plain(channelCount!)), style: caption),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «أقوى تردد» and «أضعف تردد»: the two frequencies to aim a dish with, the strongest and the
/// weakest on this satellite. Either is left out when the satellite has none.
class AlignmentAids extends StatelessWidget {
  const AlignmentAids({super.key, required this.strongest, required this.weakest});

  final Frequency? strongest;
  final Frequency? weakest;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (strongest != null)
            Expanded(
              child: _Aid(
                title: l.s5StrongestFrequency,
                color: colors.success,
                frequency: strongest!,
                state: FrequencyReadoutState.good,
              ),
            ),
          if (strongest != null && weakest != null) const SizedBox(width: MadarSpace.s2),
          if (weakest != null)
            Expanded(
              child: _Aid(
                title: l.s5WeakestFrequency,
                color: colors.error,
                frequency: weakest!,
                state: FrequencyReadoutState.bad,
              ),
            ),
        ],
      ),
    );
  }
}

class _Aid extends StatelessWidget {
  const _Aid({
    required this.title,
    required this.color,
    required this.frequency,
    required this.state,
  });

  final String title;
  final Color color;
  final Frequency frequency;
  final FrequencyReadoutState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s3,
        vertical: MadarSpace.s2,
      ),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.signal_cellular_alt, size: MadarText.textBody.fontSize, color: color),
              const SizedBox(width: MadarSpace.s1),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MadarText.textCaption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MadarSpace.s2),
          // Two aids share a phone's width, and a readout does not wrap: at a larger text
          // size it shrinks to fit its card rather than overflow.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: FrequencyReadout(
              mhz: frequency.mhz,
              polarization: frequency.pol,
              symbolRate: frequency.sr,
              state: state,
            ),
          ),
        ],
      ),
    );
  }
}

/// «طريقة استقبال القمر»: opens the satellite's reception video.
class ReceptionButton extends StatelessWidget {
  const ReceptionButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
      child: Semantics(
        button: true,
        label: l.s5ReceptionHowTo,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(MadarRadii.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MadarRadii.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.smart_display_outlined,
                    size: MadarText.textStrong.fontSize,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(width: MadarSpace.s2),
                  Text(
                    l.s5ReceptionHowTo,
                    style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
