import 'package:flutter/material.dart';

import '../../core/format/bidi.dart';
import '../../core/format/digits.dart';
import '../../core/format/time.dart';
import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';
import '../../core/network/generated/models/score.dart';
import '../../core/network/generated/models/status.dart';
import '../../l10n/app_localizations.dart';
import 'display_scope.dart';

/// The centre cell of every match row and hero: exactly one of a kickoff time, a live
/// score with its minute, a final score, or a status word.
///
/// A clock-estimated live state is «مباشر» with no score and the quieter treatment
/// (constitution II): the clock says it should be live, no feed confirms it.
class StatusBlock extends StatelessWidget {
  const StatusBlock({
    super.key,
    required this.status,
    this.kickoff,
    this.score,
    this.minute,
    this.estimated = false,
    this.timeTbd = false,
    this.use24h,
    this.now,
  });

  final Status status;
  final DateTime? kickoff;
  final Score? score;
  final String? minute;
  final bool estimated;
  final bool timeTbd;
  /// 12 vs 24 hours. Null takes the app's setting; a component test keeps the default.
  final bool? use24h;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final primary = MadarText.textLabel.copyWith(color: colors.textPrimary);
    final caption = MadarText.textCaption.copyWith(color: colors.textTertiary);

    if (status == Status.live && estimated) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(
            label: l.live,
            foreground: colors.estimated,
            background: colors.surface2,
            dashed: true,
          ),
        ],
      );
    }

    switch (status) {
      case Status.scheduled:
        if (timeTbd || kickoff == null) {
          return Text(l.timeTbd, style: primary.copyWith(color: colors.textSecondary));
        }
        final time = MadarTime.kickoff(
          kickoff,
          use24h: use24h ?? MadarDisplayScope.use24hOf(context),
          zone: MadarDisplayScope.zoneOf(context).fixed,
          am: l.amMarker,
          pm: l.pmMarker,
        );
        if (MadarTime.isImminent(kickoff!, now: now)) {
          final minutes = MadarTime.minutesUntil(kickoff!, now: now);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.imminent(MadarDigits.plain(minutes)),
                style: MadarText.textMicro.copyWith(color: colors.accentText),
              ),
              const SizedBox(height: MadarSpace.s1),
              Text(time ?? l.timeTbd, style: caption),
            ],
          );
        }
        return Text(time ?? l.timeTbd, style: MadarText.rowTime.copyWith(color: colors.textPrimary));

      case Status.live:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _scoreOrDash(context),
            const SizedBox(height: MadarSpace.s1),
            _StatusPill(
              // The minute keeps the design's "67′" in an LTR island: U+2032 is missing
              // from Changa and IBM Plex Sans Arabic but present in IBM Plex Mono.
              content: minute == null
                  ? null
                  : _minuteLabel(l.minuteShort(minute!), colors.live),
              label: minute == null ? l.live : null,
              foreground: colors.live,
              background: colors.liveContainer,
              live: true,
            ),
          ],
        );

      case Status.halftime:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _scoreOrDash(context),
            const SizedBox(height: MadarSpace.s1),
            _StatusPill(
              label: l.halftime,
              foreground: colors.halftime,
              background: colors.halftimeContainer,
            ),
          ],
        );

      case Status.extraTime:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _scoreOrDash(context),
            const SizedBox(height: MadarSpace.s1),
            _StatusPill(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (minute != null) ...[
                    _minuteLabel(l.minuteShort(minute!), colors.halftime),
                    const SizedBox(width: MadarSpace.s1),
                  ],
                  Text(
                    l.extraTime,
                    style: MadarText.textMicro.copyWith(color: colors.halftime),
                  ),
                ],
              ),
              foreground: colors.halftime,
              background: colors.halftimeContainer,
            ),
          ],
        );

      case Status.penalties:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _scoreOrDash(context),
            if (score?.homePen != null && score?.awayPen != null) ...[
              const SizedBox(height: MadarSpace.s1),
              ScoreParts(
                home: MadarDigits.plain(score!.homePen!),
                away: MadarDigits.plain(score!.awayPen!),
                separator: l.scoreSeparator,
                style: caption,
              ),
            ],
            const SizedBox(height: MadarSpace.s1),
            _StatusPill(
              label: l.penalties,
              foreground: colors.textSecondary,
              background: colors.surface3,
            ),
          ],
        );

      case Status.finished:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _scoreOrDash(context),
            const SizedBox(height: MadarSpace.s1),
            Text(l.finished, style: caption),
          ],
        );

      case Status.postponed:
        return _StatusPill(
          label: l.postponed,
          foreground: colors.postponed,
          background: colors.postponedContainer,
        );

      case Status.cancelled:
        return Text(
          l.cancelled,
          style: primary.copyWith(
            color: colors.cancelled,
            decoration: TextDecoration.lineThrough,
          ),
        );

      case Status.abandoned:
        return Text(l.abandoned, style: primary.copyWith(color: colors.cancelled));

      case Status.$unknown:
        return Text(l.timeTbd, style: primary.copyWith(color: colors.textSecondary));
    }
  }

  Widget _scoreOrDash(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    if (score == null) return const SizedBox.shrink();
    final style = MadarText.rowScore.copyWith(color: colors.textPrimary);
    return ScoreParts(
      home: MadarDigits.plain(score!.home),
      away: MadarDigits.plain(score!.away),
      separator: l.scoreSeparator,
      style: style,
      separatorStyle: style.copyWith(color: colors.textTertiary),
    );
  }
}

/// A minute as the design draws it: isolated LTR in the mono family, where U+2032 exists.
Widget _minuteLabel(String text, Color color) =>
    LtrIsland(text, style: MadarText.readout.copyWith(color: color));

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    this.label,
    this.content,
    required this.foreground,
    required this.background,
    this.dashed = false,
    this.live = false,
  }) : assert(label != null || content != null, 'a pill needs a label or content');

  final String? label;
  final Widget? content;
  final Color foreground;
  final Color background;
  final bool dashed;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s2,
        vertical: MadarSpace.s1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MadarRadii.pill),
        border: dashed ? Border.all(color: foreground.withValues(alpha: 0.7)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            const LiveDot(),
            const SizedBox(width: MadarSpace.s1),
          ],
          content ??
              Text(
                label!,
                style: MadarText.textMicro.copyWith(color: foreground),
                maxLines: 1,
              ),
        ],
      ),
    );
    if (!dashed) return child;
    return CustomPaint(painter: _DashedOutlinePainter(color: foreground), child: child);
  }
}

/// The live dot (the status pill and the «مباشر» filter chip); static when the OS asks for
/// reduced motion.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.madarColors.live;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: MadarSpace.s2,
        height: MadarSpace.s2,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _DashedOutlinePainter extends CustomPainter {
  _DashedOutlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(MadarRadii.pill),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = MadarLine.hairline
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = MadarSpace.s1;
      const gap = MadarSpace.s1;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter oldDelegate) => oldDelegate.color != color;
}
