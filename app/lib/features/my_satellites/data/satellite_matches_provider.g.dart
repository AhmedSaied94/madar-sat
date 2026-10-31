// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'satellite_matches_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
///
/// It is a different question from S2's day, so it is cached as its own document under
/// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
/// (research R25): written there it would replace S2's full day with a filtered one, and
/// filtering S2's rows locally would miss carriages, because a row's channel line holds at
/// most two.
///
/// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
/// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).

@ProviderFor(SatelliteMatches)
final satelliteMatchesProvider = SatelliteMatchesFamily._();

/// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
///
/// It is a different question from S2's day, so it is cached as its own document under
/// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
/// (research R25): written there it would replace S2's full day with a filtered one, and
/// filtering S2's rows locally would miss carriages, because a row's channel line holds at
/// most two.
///
/// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
/// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).
final class SatelliteMatchesProvider
    extends
        $StreamNotifierProvider<
          SatelliteMatches,
          SwrSnapshot<List<MatchSummary>>
        > {
  /// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
  ///
  /// It is a different question from S2's day, so it is cached as its own document under
  /// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
  /// (research R25): written there it would replace S2's full day with a filtered one, and
  /// filtering S2's rows locally would miss carriages, because a row's channel line holds at
  /// most two.
  ///
  /// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
  /// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).
  SatelliteMatchesProvider._({
    required SatelliteMatchesFamily super.from,
    required SatelliteMatchesQuery super.argument,
  }) : super(
         retry: _never,
         name: r'satelliteMatchesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$satelliteMatchesHash();

  @override
  String toString() {
    return r'satelliteMatchesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SatelliteMatches create() => SatelliteMatches();

  @override
  bool operator ==(Object other) {
    return other is SatelliteMatchesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$satelliteMatchesHash() => r'a663530c8129bfbf2351b1b94e06a8a0d5356736';

/// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
///
/// It is a different question from S2's day, so it is cached as its own document under
/// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
/// (research R25): written there it would replace S2's full day with a filtered one, and
/// filtering S2's rows locally would miss carriages, because a row's channel line holds at
/// most two.
///
/// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
/// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).

final class SatelliteMatchesFamily extends $Family
    with
        $ClassFamilyOverride<
          SatelliteMatches,
          AsyncValue<SwrSnapshot<List<MatchSummary>>>,
          SwrSnapshot<List<MatchSummary>>,
          Stream<SwrSnapshot<List<MatchSummary>>>,
          SatelliteMatchesQuery
        > {
  SatelliteMatchesFamily._()
    : super(
        retry: _never,
        name: r'satelliteMatchesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
  ///
  /// It is a different question from S2's day, so it is cached as its own document under
  /// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
  /// (research R25): written there it would replace S2's full day with a filtered one, and
  /// filtering S2's rows locally would miss carriages, because a row's channel line holds at
  /// most two.
  ///
  /// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
  /// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).

  SatelliteMatchesProvider call(SatelliteMatchesQuery query) =>
      SatelliteMatchesProvider._(argument: query, from: this);

  @override
  String toString() => r'satelliteMatchesProvider';
}

/// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
///
/// It is a different question from S2's day, so it is cached as its own document under
/// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
/// (research R25): written there it would replace S2's full day with a filtered one, and
/// filtering S2's rows locally would miss carriages, because a row's channel line holds at
/// most two.
///
/// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
/// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).

abstract class _$SatelliteMatches
    extends $StreamNotifier<SwrSnapshot<List<MatchSummary>>> {
  late final _$args = ref.$arg as SatelliteMatchesQuery;
  SatelliteMatchesQuery get query => _$args;

  Stream<SwrSnapshot<List<MatchSummary>>> build(SatelliteMatchesQuery query);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<List<MatchSummary>>>,
              SwrSnapshot<List<MatchSummary>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<List<MatchSummary>>>,
                SwrSnapshot<List<MatchSummary>>
              >,
              AsyncValue<SwrSnapshot<List<MatchSummary>>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
