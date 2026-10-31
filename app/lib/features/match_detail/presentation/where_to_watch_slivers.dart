import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/format/bidi.dart';
import '../../../core/format/digits.dart';
import '../../../core/network/generated/models/carriage_entry.dart';
import '../../../core/network/generated/models/commentator_ref.dart';
import '../../../core/network/generated/models/platform_entry.dart';
import '../../../core/network/generated/models/platform_group.dart';
import '../../../core/network/generated/models/satellite_ref.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../design/components/carriage_row.dart';
import '../../../design/components/commentator_row.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/filter_chip_row.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/search_field.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/carriage_mapper.dart';
import '../domain/carriage_order.dart';
import 'where_to_watch_state.dart';

/// The search field shows once there is more than a handful to look through.
const int _searchFrom = 7;

/// S3's "where to watch" as slivers: the toolbar, then three parts: my satellites, the
/// other satellites, and platforms.
///
/// Every group is a header followed, only while it is open, by one `SliverList.builder`, so
/// a collapsed group builds just its header and an open one builds the rows near the
/// viewport. That is what keeps a match with 171 links cheap (SC-006).
class WhereToWatchSlivers {
  const WhereToWatchSlivers({
    required this.l,
    required this.all,
    required this.shown,
    required this.state,
    required this.controller,
    required this.receptionOf,
    required this.onWatchReception,
    required this.onRefresh,
  });

  final AppLocalizations l;

  /// Every way to watch, before the toolbar's filters.
  final WhereToWatch all;

  /// [all] after the filters.
  final WhereToWatch shown;
  final WhereToWatchState state;
  final WhereToWatchController controller;

  /// The reception video of a satellite, or null when it has none.
  final Uri? Function(SatelliteRef? satellite) receptionOf;
  final void Function(Uri url) onWatchReception;
  final VoidCallback onRefresh;

  List<Widget> build() {
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _Toolbar(
          title: l.s3WhereToWatch,
          countText: all.isEmpty ? null : l.s3ChannelsCount(all.total),
          showFilters: !all.isEmpty,
          showSearch: all.total >= _searchFrom,
          freeOnly: state.freeOnly,
          onToggleFree: controller.toggleFreeOnly,
          onQuery: controller.setQuery,
        ),
      ),
    ];

    if (all.isEmpty) {
      return [...slivers, SliverToBoxAdapter(child: _NoChannels(onRefresh: onRefresh))];
    }
    if (shown.isEmpty) {
      return [...slivers, SliverToBoxAdapter(child: _Note(text: l.s3NoResults))];
    }

    // 1 · on my satellites.
    if (shown.mine.isNotEmpty) {
      slivers.addAll(
        _group(
          id: GroupIds.mine,
          defaultOpen: true,
          title: l.onMySatellites,
          subtitle: _mineNames(shown.mine),
          leading: const _GlyphTile(icon: Icons.satellite_alt, accent: true),
          highlighted: true,
          countText: l.s3ChannelsCount(shown.mine.length),
          count: shown.mine.length,
          rows: _carriageRows(shown.mine),
        ),
      );
    } else if (all.mine.isEmpty && !state.isFiltering) {
      slivers.add(SliverToBoxAdapter(child: _Note(text: l.s3NothingOnMySatellites)));
    }

    // 2 · the other satellites, the first one open.
    if (shown.otherSatellites.isNotEmpty) {
      final channels = shown.otherSatellites.fold(0, (sum, group) => sum + group.carriages.length);
      slivers.add(
        SliverToBoxAdapter(
          child: _PartTitle(
            title: l.s3OtherSatellites,
            detail: l.s3ChannelsOnSatellites(
              l.s3ChannelsCount(channels),
              l.s3SatellitesCount(shown.otherSatellites.length),
            ),
          ),
        ),
      );
      for (var i = 0; i < shown.otherSatellites.length; i++) {
        final group = shown.otherSatellites[i];
        slivers.addAll(
          _group(
            id: GroupIds.satellite(group.satellite.id),
            defaultOpen: i == 0,
            title: group.satellite.nameAr,
            subtitle: group.satellite.nameEn,
            subtitleIsLatin: true,
            leading: const _SatelliteTile(),
            countText: l.s3ChannelsCount(group.carriages.length),
            count: group.carriages.length,
            rows: _carriageRows(group.carriages),
          ),
        );
      }
    }

    // 3 · links with no satellite, and platforms by region; collapsed until opened.
    if (shown.withoutSatellite.isNotEmpty || shown.platforms.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _PartTitle(
            title: l.s3OtherPlatforms,
            detail: l.s3ChannelsCount(shown.platformCount + shown.withoutSatellite.length),
          ),
        ),
      );
      if (shown.withoutSatellite.isNotEmpty) {
        slivers.addAll(
          _group(
            id: GroupIds.withoutSatellite,
            defaultOpen: false,
            title: l.s3NoSatellite,
            leading: const _GlyphTile(icon: Icons.settings_input_antenna),
            countText: l.s3ChannelsCount(shown.withoutSatellite.length),
            count: shown.withoutSatellite.length,
            rows: _carriageRows(shown.withoutSatellite),
          ),
        );
      }
      for (final region in shown.platforms) {
        slivers.addAll(
          _group(
            id: GroupIds.region(region.region),
            defaultOpen: false,
            title: region.region,
            subtitle: l.s3PlatformsCount(region.items.length),
            leading: const _GlyphTile(icon: Icons.public),
            countText: l.s3PlatformsCount(region.items.length),
            rows: _platformRows(region),
          ),
        );
      }
    }
    return slivers;
  }

  /// The header of a group and, while it is open, its rows.
  List<Widget> _group({
    required String id,
    required bool defaultOpen,
    required String title,
    required Widget leading,
    required String countText,
    required Widget rows,
    String? subtitle,
    bool subtitleIsLatin = false,
    bool highlighted = false,
    int? count,
  }) {
    final open = state.isOpen(id, byDefault: defaultOpen);
    return [
      SliverToBoxAdapter(
        child: _GroupHeader(
          groupId: id,
          leading: leading,
          title: title,
          subtitle: subtitle,
          subtitleIsLatin: subtitleIsLatin,
          countText: countText,
          countBadge: count,
          open: open,
          highlighted: highlighted,
          // A filter keeps every group open, so a header has nothing to toggle then.
          onTap: state.isFiltering
              ? null
              : () => controller.toggleGroup(id, currentlyOpen: open),
        ),
      ),
      if (open) rows,
    ];
  }

  Widget _carriageRows(List<CarriageEntry> entries) => SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final key = carriageKey(entry);
          final video = receptionOf(entry.satellite);
          return _CarriageItem(
            key: ValueKey(key),
            entry: entry,
            expanded: state.expanded.contains(key),
            onToggle: () => controller.toggleCarriage(key),
            onWatchReception: video == null ? null : () => onWatchReception(video),
          );
        },
      );

  Widget _platformRows(PlatformGroup group) => SliverList.builder(
        itemCount: group.items.length,
        itemBuilder: (context, index) => _PlatformItem(item: group.items[index]),
      );

  /// «نايل سات · بدر»: the satellites actually carrying the match, in listed order.
  String _mineNames(List<CarriageEntry> mine) {
    final names = <String>{for (final entry in mine) ?entry.satellite?.nameAr};
    return names.join(' · ');
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.countText,
    required this.showFilters,
    required this.showSearch,
    required this.freeOnly,
    required this.onToggleFree,
    required this.onQuery,
  });

  final String title;
  final String? countText;
  final bool showFilters;
  final bool showSearch;
  final bool freeOnly;
  final VoidCallback onToggleFree;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MadarSpace.s4,
            MadarSpace.s6,
            MadarSpace.s4,
            MadarSpace.s1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title, style: MadarText.heading2.copyWith(color: colors.textPrimary)),
              if (countText != null) ...[
                const SizedBox(width: MadarSpace.s2),
                Text(
                  countText!,
                  style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ),
        if (showFilters)
          FilterChipRow<bool>(
            items: [FilterChipItem(value: true, label: l.s3FreeOnly)],
            selected: freeOnly,
            onSelected: (_) => onToggleFree(),
          ),
        if (showSearch)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              MadarSpace.s4,
              MadarSpace.s1,
              MadarSpace.s4,
              MadarSpace.s2,
            ),
            child: SearchField(
              key: const ValueKey('s3-search'),
              hint: l.s3SearchHint,
              onChanged: onQuery,
              dense: true,
            ),
          ),
      ],
    );
  }
}

/// «أقمار أخرى · 22 قناة على 8 أقمار»: the heading of a part.
class _PartTitle extends StatelessWidget {
  const _PartTitle({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s4,
        MadarSpace.s6,
        MadarSpace.s4,
        MadarSpace.s2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: MadarText.textStrong.copyWith(color: colors.textPrimary)),
          const SizedBox(width: MadarSpace.s2),
          Flexible(
            child: Text(
              detail,
              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A group's title bar: leading tile, name, count and the open/closed chevron. One merged
/// Arabic label reads the name, the count and whether the group is open.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.groupId,
    required this.leading,
    required this.title,
    required this.countText,
    required this.open,
    required this.onTap,
    this.subtitle,
    this.subtitleIsLatin = false,
    this.countBadge,
    this.highlighted = false,
  });

  final String groupId;
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool subtitleIsLatin;
  final String countText;
  final int? countBadge;
  final bool open;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final subtitleStyle = MadarText.textCaption.copyWith(color: colors.textTertiary);
    // A region's subtitle already is its count: say it once.
    final label = [title, ?subtitle, if (subtitle != countText) countText].join(l.listSeparator);

    return Semantics(
      key: ValueKey('group:$groupId'),
      container: true,
      button: onTap != null,
      expanded: open,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider, width: MadarLine.hairline)),
        ),
        child: Material(
          color: highlighted ? colors.accentContainer : colors.surface2,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MadarSpace.s12),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s3,
                  vertical: MadarSpace.s2,
                ),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: MadarSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MadarText.textStrong.copyWith(color: colors.textPrimary),
                          ),
                          if (subtitle != null)
                            subtitleIsLatin
                                ? LtrIsland(subtitle!, style: subtitleStyle)
                                : Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: subtitleStyle,
                                  ),
                        ],
                      ),
                    ),
                    if (countBadge != null) ...[
                      const SizedBox(width: MadarSpace.s2),
                      CountBadge(count: countBadge!, label: MadarDigits.plain(countBadge!)),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: MadarSpace.s2),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: MadarText.textBody.fontSize,
                        color: colors.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SatelliteTile extends StatelessWidget {
  const _SatelliteTile();

  @override
  Widget build(BuildContext context) =>
      const LogoTile(kind: LogoTileKind.satellite, size: MadarSpace.s8);
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.icon, this.accent = false});

  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      width: MadarSpace.s8,
      height: MadarSpace.s8,
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(MadarRadii.md),
        border: Border.all(color: colors.divider, width: MadarLine.hairline),
      ),
      child: Icon(
        icon,
        size: MadarText.textBody.fontSize,
        color: accent ? colors.accentText : colors.textSecondary,
      ),
    );
  }
}

/// One carriage: its `CarriageRow`, and under it the commentators of this match on this
/// channel, each with a voice clip (one plays at a time).
class _CarriageItem extends StatelessWidget {
  const _CarriageItem({
    super.key,
    required this.entry,
    required this.expanded,
    required this.onToggle,
    required this.onWatchReception,
  });

  final CarriageEntry entry;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onWatchReception;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: MadarLine.hairline, thickness: MadarLine.hairline, color: colors.divider),
        CarriageRow(
          carriage: carriageOf(entry),
          expanded: expanded,
          onTap: onToggle,
          onWatchReception: onWatchReception,
        ),
        if (entry.commentators.isNotEmpty) _Commentators(commentators: entry.commentators, expanded: expanded),
      ],
    );
  }
}

class _Commentators extends StatelessWidget {
  const _Commentators({required this.commentators, required this.expanded});

  final List<CommentatorRef> commentators;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Material(
      color: expanded ? colors.surface2 : colors.surface1,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s3,
          0,
          MadarSpace.s3,
          MadarSpace.s2,
        ),
        child: Column(
          children: [
            for (final commentator in commentators) ...[
              CommentatorRow(commentator: commentator),
              if (commentator != commentators.last) const SizedBox(height: MadarSpace.s2),
            ],
          ],
        ),
      ),
    );
  }
}

/// A streaming platform or other channel with no satellite: its name and the country it
/// airs in. No frequency, no access: the API sends neither.
class _PlatformItem extends StatelessWidget {
  const _PlatformItem({required this.item});

  final PlatformEntry item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final country = item.country;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: MadarLine.hairline, thickness: MadarLine.hairline, color: colors.divider),
        Semantics(
          container: true,
          label: [item.name, ?country].join(l.listSeparator),
          excludeSemantics: true,
          child: Material(
            color: colors.surface1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MadarSpace.s12),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s3,
                  vertical: MadarSpace.s2,
                ),
                child: Row(
                  children: [
                    LogoTile(
                      kind: LogoTileKind.channel,
                      logo: item.logo == null ? null : CachedNetworkImageProvider(item.logo!),
                      fallbackText: item.name,
                      size: MadarSpace.s5 * 2,
                    ),
                    const SizedBox(width: MadarSpace.s2),
                    Expanded(
                      child: EntityName(
                        item.name,
                        style: MadarText.textStrong.copyWith(color: colors.textPrimary),
                      ),
                    ),
                    if (country != null) ...[
                      const SizedBox(width: MadarSpace.s2),
                      Text(
                        country,
                        style: MadarText.textMicro.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s4,
      ),
      child: Text(text, style: MadarText.textBody.copyWith(color: colors.textSecondary)),
    );
  }
}

/// «لم تُضف القنوات الناقلة بعد», with «تحديث» as the next action until follows arrive on D3
/// (constitution I: a state always offers one).
class _NoChannels extends StatelessWidget {
  const _NoChannels({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return EmptyState(
      title: l.s3NoChannelsTitle,
      body: l.s3NoChannelsBody,
      action: FilledButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
        label: Text(l.s3Refresh),
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          minimumSize: const Size(MadarLayout.touchMin, MadarLayout.touchMin),
        ),
      ),
    );
  }
}
