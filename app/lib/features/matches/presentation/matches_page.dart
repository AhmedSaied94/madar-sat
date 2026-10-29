import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/error_copy.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/match_row.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../matches/data/matches_api.dart';
import 'matches_providers.dart';

/// S2 Matches: the device's local day of matches from `/v1/matches`.
///
/// D1 renders unstyled rows; the grouped list, filters and date strip arrive with S2 on
/// D2 (plan.md Complexity Tracking for the missing stale-while-revalidate repository).
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final matches = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            MadarTopBar.root(onSearch: () => context.go('/search')),
            Expanded(
              child: switch (matches) {
                AsyncError(:final error) => EmptyState(
                    kind: EmptyStateKind.error,
                    title: l.loadFailedTitle,
                    body: l.errorCopy(_codeOf(error)),
                    action: TextButton(
                      onPressed: () => ref.invalidate(matchesProvider),
                      child: Text(l.retry),
                    ),
                  ),
                AsyncData(:final value) => value.isEmpty
                    ? EmptyState(
                        title: l.emptyDayTitle,
                        body: l.emptyDayBody,
                      )
                    : ListView.separated(
                        itemCount: value.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: colors.divider),
                        itemBuilder: (context, index) {
                          final match = value[index];
                          return MatchRow(
                            match: match,
                            onTap: () => context.go('/match/${match.id}'),
                          );
                        },
                      ),
                _ => const Skeleton(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: MadarBottomNav(
        current: MadarTab.matches,
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

  static String? _codeOf(Object error) => error is MatchesFailure ? error.code : null;
}
