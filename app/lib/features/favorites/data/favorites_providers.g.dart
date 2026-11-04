// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// «مبارياتي القادمة»: the next three matches of what the person follows (S9).
///
/// Read from drift, which already holds the kept days' matches (D2), so the section works
/// offline; a followed team or match with nothing in the window simply adds nothing. The
/// order is by kickoff, then id, so two matches at the same minute never swap places.

@ProviderFor(favoriteUpcoming)
final favoriteUpcomingProvider = FavoriteUpcomingProvider._();

/// «مبارياتي القادمة»: the next three matches of what the person follows (S9).
///
/// Read from drift, which already holds the kept days' matches (D2), so the section works
/// offline; a followed team or match with nothing in the window simply adds nothing. The
/// order is by kickoff, then id, so two matches at the same minute never swap places.

final class FavoriteUpcomingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MatchSummary>>,
          List<MatchSummary>,
          FutureOr<List<MatchSummary>>
        >
    with
        $FutureModifier<List<MatchSummary>>,
        $FutureProvider<List<MatchSummary>> {
  /// «مبارياتي القادمة»: the next three matches of what the person follows (S9).
  ///
  /// Read from drift, which already holds the kept days' matches (D2), so the section works
  /// offline; a followed team or match with nothing in the window simply adds nothing. The
  /// order is by kickoff, then id, so two matches at the same minute never swap places.
  FavoriteUpcomingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteUpcomingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteUpcomingHash();

  @$internal
  @override
  $FutureProviderElement<List<MatchSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MatchSummary>> create(Ref ref) {
    return favoriteUpcoming(ref);
  }
}

String _$favoriteUpcomingHash() => r'8933c811764d82d05243badfa7b01d1521f5ba20';

/// The followed teams with their names and competitions, from `/v1/teams/{id}` through the
/// SWR cache: S9 shows a team the cached matches know nothing about.
///
/// One request per followed team the first time, then a conditional `If-None-Match`; a team
/// that cannot be read is left out rather than drawn with a guessed name.

@ProviderFor(favoriteTeams)
final favoriteTeamsProvider = FavoriteTeamsProvider._();

/// The followed teams with their names and competitions, from `/v1/teams/{id}` through the
/// SWR cache: S9 shows a team the cached matches know nothing about.
///
/// One request per followed team the first time, then a conditional `If-None-Match`; a team
/// that cannot be read is left out rather than drawn with a guessed name.

final class FavoriteTeamsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TeamDetail>>,
          List<TeamDetail>,
          FutureOr<List<TeamDetail>>
        >
    with $FutureModifier<List<TeamDetail>>, $FutureProvider<List<TeamDetail>> {
  /// The followed teams with their names and competitions, from `/v1/teams/{id}` through the
  /// SWR cache: S9 shows a team the cached matches know nothing about.
  ///
  /// One request per followed team the first time, then a conditional `If-None-Match`; a team
  /// that cannot be read is left out rather than drawn with a guessed name.
  FavoriteTeamsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteTeamsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteTeamsHash();

  @$internal
  @override
  $FutureProviderElement<List<TeamDetail>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TeamDetail>> create(Ref ref) {
    return favoriteTeams(ref);
  }
}

String _$favoriteTeamsHash() => r'7cf2ec2a94888e2052d0776ba3a504a4c2b5cea5';

/// The followed competitions with their names and logos, from `/v1/competitions/{id}` through
/// the SWR cache: S9 lists a competition the cached matches know nothing about, and its row
/// opens S8 (T086).
///
/// One request per followed competition the first time, then a conditional `If-None-Match`; a
/// competition that cannot be read is left out rather than drawn with a guessed name.

@ProviderFor(favoriteCompetitions)
final favoriteCompetitionsProvider = FavoriteCompetitionsProvider._();

/// The followed competitions with their names and logos, from `/v1/competitions/{id}` through
/// the SWR cache: S9 lists a competition the cached matches know nothing about, and its row
/// opens S8 (T086).
///
/// One request per followed competition the first time, then a conditional `If-None-Match`; a
/// competition that cannot be read is left out rather than drawn with a guessed name.

final class FavoriteCompetitionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CompetitionDetail>>,
          List<CompetitionDetail>,
          FutureOr<List<CompetitionDetail>>
        >
    with
        $FutureModifier<List<CompetitionDetail>>,
        $FutureProvider<List<CompetitionDetail>> {
  /// The followed competitions with their names and logos, from `/v1/competitions/{id}` through
  /// the SWR cache: S9 lists a competition the cached matches know nothing about, and its row
  /// opens S8 (T086).
  ///
  /// One request per followed competition the first time, then a conditional `If-None-Match`; a
  /// competition that cannot be read is left out rather than drawn with a guessed name.
  FavoriteCompetitionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteCompetitionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteCompetitionsHash();

  @$internal
  @override
  $FutureProviderElement<List<CompetitionDetail>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CompetitionDetail>> create(Ref ref) {
    return favoriteCompetitions(ref);
  }
}

String _$favoriteCompetitionsHash() =>
    r'28dcbfd25eb485ea2f2b01db660c021b51fdfdbc';
