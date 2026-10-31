import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clock.dart';
import '../../../core/format/digits.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/satellite.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/search_field.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../l10n/app_localizations.dart';
import '../../my_satellites/data/my_satellites_provider.dart';
import '../domain/satellite_filter.dart';
import 'frequencies_state.dart';
import 'satellite_card.dart';

/// S5.1 «الترددات»: every satellite, my satellites pinned first, with a search box.
class FrequenciesPage extends ConsumerStatefulWidget {
  const FrequenciesPage({super.key});

  @override
  ConsumerState<FrequenciesPage> createState() => _FrequenciesPageState();
}

class _FrequenciesPageState extends ConsumerState<FrequenciesPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellites = ref.watch(satellitesProvider);
    final snapshot = satellites.value;
    // The field writes the query; this keeps it alive while the page is, even when the list
    // below is not on screen yet. The list reads it.
    ref.listen(satelliteSearchProvider, (previous, next) {});

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TitleBar(
              title: l.navFrequencies,
              count: snapshot?.data?.length,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: MadarSpace.s4,
                vertical: MadarSpace.s1,
              ),
              child: SearchField(
                hint: l.s5SearchSatellites,
                controller: _search,
                onChanged: ref.read(satelliteSearchProvider.notifier).set,
              ),
            ),
            Expanded(
              child: snapshot == null
                  ? (satellites.hasError
                      ? _Failure(
                          error: satellites.error,
                          onRetry: () => ref.invalidate(satellitesProvider),
                        )
                      : const Skeleton())
                  : _SatelliteList(snapshot: snapshot),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MadarBottomNav(
        current: MadarTab.frequencies,
        onSelect: (tab) => switch (tab) {
          MadarTab.matches => context.go('/'),
          MadarTab.mySatellites => context.go('/my-satellites'),
          MadarTab.frequencies => context.go('/satellites'),
          MadarTab.favorites => context.go('/favorites'),
          MadarTab.more => context.go('/settings'),
        },
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s4,
        MadarSpace.s3,
        MadarSpace.s4,
        MadarSpace.s2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MadarText.heading1.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
          if (count != null)
            Text(
              l.s5SatelliteCount(MadarDigits.plain(count!)),
              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
            ),
        ],
      ),
    );
  }
}

/// The list: my satellites under «أقماري», the rest under «كل الأقمار».
class _SatelliteList extends ConsumerWidget {
  const _SatelliteList({required this.snapshot});

  final SwrSnapshot<List<Satellite>> snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final query = ref.watch(satelliteSearchProvider);
    final mineIds = ref.watch(mySatelliteIdsProvider);
    final now = ref.watch(clockProvider)().toUtc();

    final matching = filterSatellites(snapshot.data ?? const <Satellite>[], query);
    final groups = partitionSatellites(matching, isMine: (s) => mineIds.contains(s.id));
    final age = snapshot.staleAge(Freshness.satellites, now: now);
    final items = <_Item>[
      if (groups.mine.isNotEmpty) ...[
        _SectionItem(l.navSatellites),
        for (final satellite in groups.mine) _CardItem(satellite, isMine: true),
      ],
      if (groups.others.isNotEmpty) ...[
        if (groups.mine.isNotEmpty) _SectionItem(l.s5SectionAll),
        for (final satellite in groups.others) _CardItem(satellite, isMine: false),
      ],
    ];

    return RefreshIndicator(
      onRefresh: () async {
        // The whole cache, revalidate and write cycle, so the spinner waits for the server.
        try {
          await ref
              .read(swrRepositoryProvider)
              .watchDocument<List<Satellite>>(
                key: DocumentKeys.satellites,
                path: '/v1/satellites',
                parse: parseSatellites,
              )
              .drain<void>();
        } on ApiFailure {
          // Nothing cached and no answer: the screen keeps showing what it shows.
        }
        // The user may have left the tab while this ran, and a disposed `ref` throws.
        if (!ref.context.mounted) return;
        ref.invalidate(satellitesProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (age != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s4,
                  vertical: MadarSpace.s1,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StaleHint(age: age),
                ),
              ),
            ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(title: l.s5NoSatellitesTitle, body: l.s5NoSatellitesBody),
            )
          else
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => switch (items[index]) {
                _SectionItem(:final title) => _SectionHeading(title: title),
                _CardItem(:final satellite, :final isMine) => _CardTile(
                    satellite: satellite,
                    isMine: isMine,
                  ),
              },
            ),
          const SliverPadding(padding: EdgeInsetsDirectional.only(bottom: MadarSpace.s4)),
        ],
      ),
    );
  }
}

sealed class _Item {
  const _Item();
}

class _SectionItem extends _Item {
  const _SectionItem(this.title);

  final String title;
}

class _CardItem extends _Item {
  const _CardItem(this.satellite, {required this.isMine});

  final Satellite satellite;
  final bool isMine;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s4,
          MadarSpace.s4,
          MadarSpace.s4,
          MadarSpace.s2,
        ),
        child: Text(
          title,
          style: MadarText.textLabel.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.satellite, required this.isMine});

  final Satellite satellite;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Column(
      children: [
        SatelliteCard(
          satellite: satellite,
          isMine: isMine,
          // push, not go: S5.2 needs a stack to pop back to.
          onTap: () => context.push('/satellites/${satellite.id}'),
        ),
        Divider(
          height: MadarLine.hairline,
          thickness: MadarLine.hairline,
          color: colors.divider,
        ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      kind: EmptyStateKind.error,
      title: l.loadFailedTitle,
      body: l.errorCopy(error is ApiFailure ? (error! as ApiFailure).code : null),
      action: TextButton(onPressed: onRetry, child: Text(l.retry)),
    );
  }
}
