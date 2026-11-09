import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/remote_config.dart';
import '../../../../core/network/generated/models/match_detail.dart';
import '../../../../core/network/generated/models/match_event_side.dart';
import '../../../../core/theme/madar_line.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../design/components/event_timeline_item.dart';
import '../../../../design/components/stale_hint.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/lineup_layout.dart';
import '../../domain/timeline.dart';
import 'lineups_lists.dart';
import 'lineups_pitch.dart';

enum _Tab { events, lineups }

/// S3's live center, right after the hero (FR-051, contract app-screens).
///
/// With the flag off, or no events and no lineups, it adds nothing, with no empty frame. An
/// estimated state shows only the note, and that gate is its own check because
/// `detailWithLiveState` keeps the events (FR-057). Cached events show with their age: with no
/// live state the merge already made the match non-live, so the timeline is chronological and
/// carries no score (FR-058).
class LiveCenterSliver extends ConsumerStatefulWidget {
  const LiveCenterSliver({super.key, required this.match, this.age});

  /// The match as the user may see it, after `detailWithLiveState`.
  final MatchDetail match;

  /// The cached copy's age, once it's past its target.
  final Duration? age;

  @override
  ConsumerState<LiveCenterSliver> createState() => _LiveCenterSliverState();
}

class _LiveCenterSliverState extends ConsumerState<LiveCenterSliver> {
  _Tab? _chosen;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    if (!ref.watch(liveCenterEnabledProvider)) return const SliverToBoxAdapter();
    if (match.estimated) return const SliverToBoxAdapter(child: _EstimatedNote());

    final rows = buildTimeline(match.events, match.score, match.status);
    final layout = ref.watch(lineupsEnabledProvider) ? layoutLineups(match.lineups) : null;
    if (rows.isEmpty && layout == null) return const SliverToBoxAdapter();

    final _Tab tab;
    if (layout == null) {
      tab = _Tab.events;
    } else if (rows.isEmpty) {
      // Nothing to show under «الأحداث» yet, and a blank panel says nothing.
      tab = _Tab.lineups;
      _chosen ??= tab;
    } else {
      // Kept once shown, so the first event never flips the panel under someone reading.
      tab = _chosen ??= _Tab.events;
    }
    final age = widget.age;
    return SliverMainAxisGroup(
      slivers: [
        if (age != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MadarSpace.s4,
                MadarSpace.s2,
                MadarSpace.s4,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StaleHint(age: age),
              ),
            ),
          ),
        if (layout != null)
          SliverToBoxAdapter(
            child: _Tabs(
              selected: tab,
              hasEvents: rows.isNotEmpty,
              onSelect: (next) => setState(() => _chosen = next),
            ),
          ),
        if (tab == _Tab.events)
          _TimelineSliver(match: match, rows: rows)
        else
          switch (layout) {
            LineupPitch() => SliverToBoxAdapter(
                child: LineupsPitch(match: match, layout: layout),
              ),
            LineupLists() => LineupsListsSliver(match: match, layout: layout),
            null => const SliverToBoxAdapter(),
          },
      ],
    );
  }
}

/// «بدون نتيجة»: no timeline, score or minute, because no feed stands behind this state.
class _EstimatedNote extends StatelessWidget {
  const _EstimatedNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s3,
      ),
      child: Text(
        l.lcEstimatedNote,
        textAlign: TextAlign.center,
        style: MadarText.textCaption.copyWith(color: context.madarColors.textTertiary),
      ),
    );
  }
}

/// «الأحداث» and «التشكيل». Screen-local, not in `INDEX.md`.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.hasEvents, required this.onSelect});

  final _Tab selected;
  final bool hasEvents;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Semantics(
      container: true,
      label: l.lcTabsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider, width: MadarLine.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
          child: Row(
            children: [
              _TabButton(
                label: l.lcTabEvents,
                selected: selected == _Tab.events,
                onTap: hasEvents ? () => onSelect(_Tab.events) : null,
              ),
              const SizedBox(width: MadarSpace.s5),
              _TabButton(
                label: l.lcTabLineups,
                selected: selected == _Tab.lineups,
                onTap: () => onSelect(_Tab.lineups),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;

  /// Null while the tab has nothing to show.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? colors.accent : colors.bg.withValues(alpha: 0),
                  width: MadarSpace.s1,
                ),
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: MadarText.textLabel.copyWith(
                  color: selected
                      ? colors.textPrimary
                      : onTap == null
                          ? colors.textDisabled
                          : colors.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineSliver extends StatelessWidget {
  const _TimelineSliver({required this.match, required this.rows});

  final MatchDetail match;
  final List<TimelineRow> rows;

  String _markerLabel(AppLocalizations l, TimelineMarkerKind kind) => switch (kind) {
        TimelineMarkerKind.kickoff => l.tlKickoff,
        TimelineMarkerKind.secondHalf => l.tlSecondHalf,
        TimelineMarkerKind.extraTime => l.extraTime,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SliverPadding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s2,
      ),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) => switch (rows[index]) {
          TimelineMarker(:final kind) => TimelineMarkerRow(label: _markerLabel(l, kind)),
          TimelineEventRow(:final event, :final runningScore) => EventTimelineItem(
              event: event,
              runningScore: runningScore,
              teamName: event.side == MatchEventSide.home ? match.home.name : match.away.name,
            ),
        },
      ),
    );
  }
}
