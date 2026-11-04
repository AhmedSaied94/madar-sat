import 'package:flutter/material.dart';

import '../../../core/format/digits.dart';
import '../../../core/format/bidi.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/network/generated/models/access.dart';
import '../../../core/network/generated/models/category.dart';
import '../../../core/network/generated/models/channel_carriage.dart';
import '../../../core/network/generated/models/frequency.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/generated/models/polarization.dart';
import '../../../core/network/generated/models/status.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../design/components/button.dart';
import '../../../design/components/display_scope.dart';
import '../../../design/components/frequency_readout.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/status_block.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/channel_sections.dart';

/// The sheet's heading: the channel's logo, its name, its category and country, and the share
/// action. The whole block reads as one Arabic label.
class ChannelSheetHeader extends StatelessWidget {
  const ChannelSheetHeader({
    super.key,
    required this.detail,
    required this.name,
    required this.onShare,
  });

  final ChannelSheetHeaderData detail;

  /// The name as the sheet draws it (the display name when the API sends one).
  final String name;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final category = detail.category;
    final country = detail.country;
    final words = [
      name,
      if (category != null) category == Category.sports ? l.categorySports : l.categoryEntertainment,
      ?country,
    ];

    return Semantics(
      container: true,
      label: words.join(l.listSeparator),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LogoTile(
            kind: LogoTileKind.channel,
            logo: detail.logo,
            fallbackText: name,
            size: MadarSpace.s12 + MadarSpace.s4,
          ),
          const SizedBox(width: MadarSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityName(
                  name,
                  style: MadarText.heading2.copyWith(color: colors.textPrimary),
                ),
                if (category != null || country != null) ...[
                  const SizedBox(height: MadarSpace.s1),
                  Wrap(
                    spacing: MadarSpace.s2,
                    runSpacing: MadarSpace.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (category != null) CategoryBadge(sports: category == Category.sports),
                      if (country != null)
                        Text(
                          country,
                          style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: MadarSpace.s2),
          IconButton(
            tooltip: l.s6Share,
            onPressed: onShare,
            icon: Icon(Icons.share_outlined, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// What the header needs, so the widget can be built in a golden or a component test.
class ChannelSheetHeaderData {
  const ChannelSheetHeaderData({
    required this.logo,
    required this.category,
    required this.country,
  });

  final ImageProvider? logo;
  final Category? category;
  final String? country;
}

/// The carriage card: the satellite the channel airs on, the readout with its copy action, the
/// access and the tuning in words.
class CarriageCard extends StatelessWidget {
  const CarriageCard({
    super.key,
    required this.carriage,
    required this.isMine,
    required this.onCopy,
  });

  final ChannelCarriageView carriage;

  /// True when the satellite is one of the person's own (S5's «طبقي» marker).
  final bool isMine;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final frequency = carriage.frequency;
    final note = carriage.frequencyNote;

    return Container(
      padding: const EdgeInsetsDirectional.all(MadarSpace.s3),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(MadarRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.satellite_alt_outlined,
                size: MadarText.textCaption.fontSize,
                color: colors.textSecondary,
              ),
              const SizedBox(width: MadarSpace.s2),
              Flexible(
                child: Text(
                  carriage.satelliteNameAr ?? l.satellite,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                ),
              ),
              if (carriage.satelliteNameEn case final latin?) ...[
                const SizedBox(width: MadarSpace.s2),
                Flexible(
                  child: LtrIsland(
                    latin,
                    style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                  ),
                ),
              ],
              const Spacer(),
              if (isMine) _MineMarker(label: l.s5MineMarker),
            ],
          ),
          const SizedBox(height: MadarSpace.s3),
          // A wrap, not a row: at 1.3× the readout and the copy action drop onto two lines
          // instead of pushing each other off the card.
          Wrap(
            spacing: MadarSpace.s2,
            runSpacing: MadarSpace.s2,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (frequency != null)
                IntrinsicWidth(
                  child: MadarButton(
                    label: l.s6Copy,
                    icon: Icons.copy_outlined,
                    size: MadarButtonSize.small,
                    onPressed: onCopy,
                  ),
                ),
              frequency != null
                  ? FrequencyReadout(
                      mhz: frequency.mhz,
                      polarization: frequency.pol,
                      symbolRate: frequency.sr,
                      size: FrequencyReadoutSize.lg,
                    )
                  : FrequencyReadout(
                      note: note,
                      state: FrequencyReadoutState.note,
                      size: FrequencyReadoutSize.lg,
                    ),
            ],
          ),
          const SizedBox(height: MadarSpace.s3),
          Row(
            children: [
              AccessBadge(
                access: carriage.access ?? Access.$unknown,
                provider: carriage.provider,
              ),
              if (frequency != null) ...[
                const SizedBox(width: MadarSpace.s2),
                Expanded(
                  child: Text(
                    l.s6TuningWords(_polarization(l, frequency.pol), MadarDigits.plain(frequency.sr)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
          if (carriage.package case final package?) ...[
            const SizedBox(height: MadarSpace.s2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: EntityName(
                package,
                style: MadarText.textCaption.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _polarization(AppLocalizations l, Polarization pol) => switch (pol) {
        Polarization.h => l.polHorizontal,
        Polarization.v => l.polVertical,
        Polarization.l => l.polLeft,
        Polarization.r => l.polRight,
        _ => '',
      };
}

class _MineMarker extends StatelessWidget {
  const _MineMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s2,
        vertical: MadarSpace.s1 / 2,
      ),
      decoration: BoxDecoration(
        color: colors.accentContainer,
        borderRadius: BorderRadius.circular(MadarRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings_input_antenna, size: MadarText.textMicro.fontSize, color: colors.accentText),
          const SizedBox(width: MadarSpace.s1),
          Text(label, style: MadarText.textMicro.copyWith(color: colors.accentText)),
        ],
      ),
    );
  }
}

/// «تابع القناة · تنبيه عند تغيّر التردد»: the follow toggle, with the reason it is worth it.
class FollowChannelButton extends StatelessWidget {
  const FollowChannelButton({
    super.key,
    required this.following,
    required this.onPressed,
  });

  final bool following;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MadarButton(
          label: following ? l.s6FollowingChannel : l.s6FollowChannel,
          icon: following ? Icons.check : Icons.notifications_none,
          variant: following ? MadarButtonVariant.secondary : MadarButtonVariant.outline,
          expanded: true,
          onPressed: onPressed,
        ),
        const SizedBox(height: MadarSpace.s1),
        Text(
          l.s6FollowChannelHint,
          textAlign: TextAlign.center,
          style: MadarText.textCaption.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// «على أقمار أخرى»: the same channel on the other satellites it is carried on.
class OtherCarriagesSection extends StatelessWidget {
  const OtherCarriagesSection({super.key, required this.carriages});

  final List<ChannelCarriage> carriages;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l.s6OtherSatellites),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.madarColors.surface1,
            borderRadius: BorderRadius.circular(MadarRadii.xl),
            border: Border.all(color: context.madarColors.divider, width: MadarLine.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MadarRadii.xl),
            child: Column(
              children: [
                for (final (index, carriage) in carriages.indexed) ...[
                  if (index != 0) const _Hairline(),
                  _OtherCarriageRow(carriage: carriage),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OtherCarriageRow extends StatelessWidget {
  const _OtherCarriageRow({required this.carriage});

  final ChannelCarriage carriage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final frequency = carriage.frequency;
    final satellite = carriage.satellite;
    final name = carriage.displayName ?? carriage.name;
    final tuning = frequency == null
        ? carriage.frequencyNote
        : '${MadarDigits.plain(frequency.mhz)} ${frequency.pol.json ?? ''} '
            '${MadarDigits.plain(frequency.sr)}';
    final parts = [
      name,
      ?satellite?.nameAr,
      ?satellite?.nameEn,
      ?tuning,
      if (carriage.access == Access.free) l.free,
    ];

    return Semantics(
      container: true,
      label: parts.join(l.listSeparator),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s3,
          vertical: MadarSpace.s2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.satellite_alt_outlined,
              size: MadarText.textCaption.fontSize,
              color: colors.textSecondary,
            ),
            const SizedBox(width: MadarSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    satellite?.nameAr ?? l.satellite,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                  ),
                  if (satellite?.nameEn case final latin?)
                    LtrIsland(
                      latin,
                      style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: MadarSpace.s2),
            if (frequency != null)
              FrequencyReadout(
                mhz: frequency.mhz,
                polarization: frequency.pol,
                symbolRate: frequency.sr,
              )
            else if (carriage.frequencyNote case final note?)
              FrequencyReadout(note: note, state: FrequencyReadoutState.note),
            if (carriage.access == Access.free) ...[
              const SizedBox(width: MadarSpace.s2),
              Icon(Icons.lock_open_outlined, size: MadarText.textMicro.fontSize, color: colors.free),
            ],
          ],
        ),
      ),
    );
  }
}

/// «المباريات القادمة على القناة»: the channel's next matches, one row each, and the empty copy
/// when the channel has none in the API's seven-day window.
class ChannelUpcomingSection extends StatelessWidget {
  const ChannelUpcomingSection({
    super.key,
    required this.matches,
    required this.onOpen,
    required this.now,
  });

  final List<MatchSummary> matches;
  final ValueChanged<MatchSummary> onOpen;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l.s6UpcomingOnChannel),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s3),
            child: Text(
              l.s7NoUpcoming,
              style: MadarText.textBody.copyWith(color: colors.textSecondary),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: BorderRadius.circular(MadarRadii.xl),
              border: Border.all(color: colors.divider, width: MadarLine.hairline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MadarRadii.xl),
              child: Column(
                children: [
                  for (final (index, match) in matches.indexed) ...[
                    if (index != 0) const _Hairline(),
                    ChannelMatchRow(
                      match: match,
                      now: now,
                      onTap: () => onOpen(match),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One of S6's match rows: the day and the status block (the time, or the live minute and
/// score), the two teams, the competition, and the chevron into S3. One merged Arabic label
/// reads all of it.
class ChannelMatchRow extends StatelessWidget {
  const ChannelMatchRow({
    super.key,
    required this.match,
    required this.now,
    required this.onTap,
  });

  final MatchSummary match;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final zone = MadarDisplayScope.zoneOf(context);
    final kickoff = match.kickoffAt;
    final wall = kickoff == null ? null : zone.wallClock(kickoff);
    final today = zone.wallClock(now);
    final day = wall == null
        ? l.timeTbd
        : wall.year == today.year && wall.month == today.month && wall.day == today.day
            ? l.today
            : l.weekdayDay(MadarDates.weekday(l, wall), MadarDigits.plain(wall.day));
    // The board reads the home team first; the semantics label says it the long way round.
    final teams = '${match.home.name} × ${match.away.name}';
    final live = match.status == Status.live || match.status == Status.halftime;

    return Semantics(
      container: true,
      button: true,
      label: [l.vs(match.away.name, match.home.name), day, match.competition.name].join(l.listSeparator),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface1,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MadarSpace.s3,
                vertical: MadarSpace.s2,
              ),
              child: Row(
                children: [
                  SizedBox(
                    // The design's day column, widened with the text scale so «4:00 م» never
                    // breaks onto a second line at 1.3×.
                    width: MediaQuery.textScalerOf(context).scale(MadarSpace.s12 + MadarSpace.s6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textMicro.copyWith(
                            color: live ? colors.live : colors.textTertiary,
                          ),
                        ),
                        StatusBlock(
                          status: match.status,
                          kickoff: match.kickoffAt,
                          score: match.score,
                          minute: match.minute,
                          estimated: match.estimated,
                          timeTbd: match.timeTbd,
                          now: now,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MadarSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          teams,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                        ),
                        Text(
                          match.competition.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textMicro.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MadarSpace.s1),
                  Icon(
                    Icons.chevron_right,
                    size: MadarText.textBody.fontSize,
                    color: colors.textTertiary,
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

/// «سجل التردد»: the last three changes, each read old → new with its date.
class FrequencyHistorySection extends StatelessWidget {
  const FrequencyHistorySection({super.key, required this.changes});

  final List<FrequencyChangeView> changes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: l.s6FrequencyHistory),
        for (final (index, change) in changes.indexed) ...[
          if (index != 0) const _Hairline(),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s2),
            child: Wrap(
              spacing: MadarSpace.s2,
              runSpacing: MadarSpace.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _DateChip(label: MadarDates.dayMonth(l, change.detectedAt.toLocal())),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Tuning(frequency: change.before, note: change.beforeNote, dim: true),
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s2),
                      child: Icon(
                        // An arrow forward mirrors in RTL and points left, the way «من 11766
                        // إلى 11013» reads.
                        Icons.arrow_forward,
                        size: MadarText.textCaption.fontSize,
                        color: colors.textTertiary,
                      ),
                    ),
                    _Tuning(frequency: change.after, note: change.afterNote, dim: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s2,
        vertical: MadarSpace.s1 / 2,
      ),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(MadarRadii.sm),
      ),
      child: Text(
        label,
        style: MadarText.textMicro.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

class _Tuning extends StatelessWidget {
  const _Tuning({required this.frequency, required this.note, required this.dim});

  final Frequency? frequency;
  final String? note;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final current = frequency;
    if (current == null) {
      return FrequencyReadout(note: note, state: FrequencyReadoutState.note);
    }
    return FrequencyReadout(
      mhz: current.mhz,
      polarization: current.pol,
      state: dim ? FrequencyReadoutState.dim : FrequencyReadoutState.ok,
    );
  }
}

/// A part's heading inside the sheet.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s1,
        MadarSpace.s5,
        MadarSpace.s1,
        MadarSpace.s2,
      ),
      child: Text(
        title,
        style: MadarText.textLabel.copyWith(
          color: context.madarColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) =>
      Divider(height: MadarLine.hairline, thickness: MadarLine.hairline, color: context.madarColors.divider);
}
