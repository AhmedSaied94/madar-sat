import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clock.dart';
import '../../../core/format/digits.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/category.dart';
import '../../../core/network/generated/models/channel_carriage.dart';
import '../../../core/network/generated/models/satellite.dart';
import '../../../core/network/swr_repository.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/search_field.dart';
import '../../../design/components/segmented.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../data/satellite_channels_provider.dart';
import '../domain/channel_filter.dart';
import 'channel_list.dart';
import 'frequencies_state.dart';
import 'open_reception.dart';
import 'satellite_header.dart';

/// The tabs, in reading order: sports on the right, entertainment on the left.
const List<Category> _tabs = [Category.sports, Category.entertainment];

/// S5.2: one satellite's channels. Pushed from S5.1, so it has a back arrow.
///
/// The whole channel list is fetched once; the category switch (also by swiping) and the
/// search only filter it, so neither costs a request.
class SatelliteChannelsPage extends ConsumerStatefulWidget {
  const SatelliteChannelsPage({super.key, required this.satelliteId});

  final int satelliteId;

  @override
  ConsumerState<SatelliteChannelsPage> createState() => _SatelliteChannelsPageState();
}

class _SatelliteChannelsPageState extends ConsumerState<SatelliteChannelsPage> {
  static const Duration _slide = Duration(milliseconds: 250);

  late final PageController _pages;
  final TextEditingController _search = TextEditingController();

  int get _id => widget.satelliteId;

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _tabs.indexOf(ref.read(selectedCategoryProvider(_id))));
  }

  @override
  void dispose() {
    _pages.dispose();
    _search.dispose();
    super.dispose();
  }

  void _goTo(Category category) {
    ref.read(selectedCategoryProvider(_id).notifier).select(category);
    if (!_pages.hasClients) return;
    final index = _tabs.indexOf(category);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pages.jumpToPage(index);
    } else {
      unawaited(_pages.animateToPage(index, duration: _slide, curve: Curves.easeOutCubic));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    // The field and the rows write these; keeping them alive here means a keystroke or a tap
    // never reaches a provider that has been disposed, and rebuilds only the lists that read them.
    ref
      ..listen(channelSearchProvider(_id), (previous, next) {})
      ..listen(expandedChannelProvider(_id), (previous, next) {});

    final satellite = ref.watch(satelliteByIdProvider(_id));
    final answer = ref.watch(satelliteChannelsProvider(_id));
    final category = ref.watch(selectedCategoryProvider(_id));
    final snapshot = answer.value;
    final channels = snapshot?.data;
    final now = ref.watch(clockProvider)().toUtc();
    final age = snapshot?.staleAge(Freshness.channels, now: now);
    final reception = httpsUri(satellite?.receptionUrl);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            MadarTopBar.detail(
              title: l.navFrequencies,
              onBack: () => context.canPop() ? context.pop() : context.go('/satellites'),
            ),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._header(satellite, channels, reception),
                        if (channels != null) ...[
                          const SizedBox(height: MadarSpace.s3),
                          _Controls(
                            channels: channels,
                            category: category,
                            controller: _search,
                            onCategory: _goTo,
                            onSearch: ref.read(channelSearchProvider(_id).notifier).set,
                          ),
                          if (age != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: MadarSpace.s4,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: StaleHint(age: age),
                              ),
                            ),
                        ],
                        const SizedBox(height: MadarSpace.s2),
                      ],
                    ),
                  ),
                ],
                body: channels == null
                    ? (answer.hasError
                        ? _Failure(
                            error: answer.error,
                            onRetry: () => ref.invalidate(satelliteChannelsProvider(_id)),
                          )
                        : const Skeleton())
                    : PageView(
                        controller: _pages,
                        onPageChanged: (index) =>
                            ref.read(selectedCategoryProvider(_id).notifier).select(_tabs[index]),
                        children: [
                          for (final tab in _tabs)
                            ChannelList(
                              satelliteId: _id,
                              category: tab,
                              channels: channels,
                              receptionUrl: reception,
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The header, the alignment aids and the reception button: from the satellite list when it
  /// holds this satellite, else from the satellite the channels name.
  List<Widget> _header(Satellite? satellite, List<ChannelCarriage>? channels, Uri? reception) {
    final named = channels?.map((c) => c.satellite).nonNulls.firstOrNull;
    final nameAr = satellite?.nameAr ?? named?.nameAr;
    final nameEn = satellite?.nameEn ?? named?.nameEn;
    if (nameAr == null || nameEn == null) return const [];
    return [
      SatelliteHeader(
        nameAr: nameAr,
        nameEn: nameEn,
        position: satellite != null ? satellite.orbitalPosition : named?.orbitalPosition,
        channelCount: channels?.length ?? satellite?.channelCount,
      ),
      if (satellite?.bestFrequency != null || satellite?.worstFrequency != null) ...[
        AlignmentAids(strongest: satellite?.bestFrequency, weakest: satellite?.worstFrequency),
        const SizedBox(height: MadarSpace.s2),
      ],
      if (reception != null)
        ReceptionButton(onTap: () => openReception(context, ref, reception)),
    ];
  }
}

/// The category switch and the channel search.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.channels,
    required this.category,
    required this.controller,
    required this.onCategory,
    required this.onSearch,
  });

  final List<ChannelCarriage> channels;
  final Category category;
  final TextEditingController controller;
  final ValueChanged<Category> onCategory;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final counts = channelCounts(channels);
    String tab(String label, int count) =>
        count == 0 ? label : l.s5CategoryTab(MadarDigits.plain(count), label);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Segmented<Category>(
            options: [
              SegmentedOption(value: Category.sports, label: tab(l.categorySports, counts.sports)),
              SegmentedOption(
                value: Category.entertainment,
                label: tab(l.categoryEntertainment, counts.entertainment),
              ),
            ],
            selected: category,
            onChanged: onCategory,
          ),
          const SizedBox(height: MadarSpace.s2),
          SearchField(
            hint: l.s5SearchChannels,
            controller: controller,
            onChanged: onSearch,
            dense: true,
          ),
        ],
      ),
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
