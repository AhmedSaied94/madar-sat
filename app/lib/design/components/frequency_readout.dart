import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/bidi.dart';
import '../../core/format/digits.dart';
import '../../core/theme/madar_tokens.dart';
import '../../core/network/generated/models/polarization.dart';
import '../../l10n/app_localizations.dart';

enum FrequencyReadoutSize { standard, lg, xl }

enum FrequencyReadoutState { ok, dim, note, good, bad }

/// The equipment-style tuning display: frequency, polarization and symbol rate.
///
/// It keeps its dark well and LTR order in both themes (constitution IV): it is a
/// display, not a surface. Tapping copies exactly `11843 H 27500`.
class FrequencyReadout extends StatelessWidget {
  const FrequencyReadout({
    super.key,
    this.mhz,
    this.polarization,
    this.symbolRate,
    this.note,
    this.size = FrequencyReadoutSize.standard,
    this.state = FrequencyReadoutState.ok,
    this.onTap,
  });

  final int? mhz;
  final Polarization? polarization;
  final int? symbolRate;
  final String? note;
  final FrequencyReadoutSize size;
  final FrequencyReadoutState state;
  final VoidCallback? onTap;

  String get copyText => [
        if (mhz != null) MadarDigits.plain(mhz!),
        if (polarization?.json != null) polarization!.json!,
        if (symbolRate != null) MadarDigits.plain(symbolRate!),
      ].join(' ');

  static String polarizationLetter(Polarization? pol) => pol?.json ?? '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final style = switch (size) {
      FrequencyReadoutSize.standard => MadarText.readout,
      FrequencyReadoutSize.lg => MadarText.readoutLg,
      FrequencyReadoutSize.xl => MadarText.readoutXl,
    };
    final outline = switch (state) {
      FrequencyReadoutState.good => colors.success,
      FrequencyReadoutState.bad => colors.error,
      _ => colors.readoutLine,
    };
    final isNote = state == FrequencyReadoutState.note || mhz == null;
    final label = isNote
        ? '${l.frequency}: ${note ?? ''}'
        : [
            '${l.frequency} ${MadarDigits.plain(mhz!)}',
            if (polarization?.json != null) _polarizationWord(l, polarization),
            if (symbolRate != null) '${l.symbolRate} ${MadarDigits.plain(symbolRate!)}',
          ].join(l.listSeparator);

    return Semantics(
      label: label,
      button: onTap == null && !isNote,
      child: GestureDetector(
        onTap: isNote
            ? null
            : (onTap ?? () => Clipboard.setData(ClipboardData(text: copyText))),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: MadarSpace.s2,
            vertical: MadarSpace.s1,
          ),
          decoration: BoxDecoration(
            color: colors.readoutBg,
            borderRadius: BorderRadius.circular(MadarRadii.sm),
            border: Border.all(color: outline),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: isNote
                ? Text(
                    note ?? '',
                    style: style.copyWith(color: colors.readoutDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MadarDigits.plain(mhz!),
                        style: style.copyWith(
                          color: colors.readout,
                          shadows: context.madarShadows.readoutGlow,
                        ),
                      ),
                      const SizedBox(width: MadarSpace.s2),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: MadarSpace.s1,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(MadarRadii.xs),
                          border: Border.all(color: colors.readoutLine),
                        ),
                        child: Text(
                          polarizationLetter(polarization),
                          style: style.copyWith(color: colors.readout),
                        ),
                      ),
                      const SizedBox(width: MadarSpace.s2),
                      if (symbolRate != null)
                        Text(
                          MadarDigits.plain(symbolRate!),
                          style: style.copyWith(color: colors.readoutDim),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static String _polarizationWord(AppLocalizations l, Polarization? pol) =>
      switch (pol) {
        Polarization.h => l.polHorizontal,
        Polarization.v => l.polVertical,
        Polarization.l => l.polLeft,
        Polarization.r => l.polRight,
        _ => '',
      };
}

/// The whole tuning as one LTR island, for a collapsed row's second line.
String frequencyIsland({
  required int mhz,
  required Polarization pol,
  required int symbolRate,
}) =>
    isolateLtr('${MadarDigits.plain(mhz)} ${pol.json} ${MadarDigits.plain(symbolRate)}');
