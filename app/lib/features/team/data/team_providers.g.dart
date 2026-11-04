// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
/// the cached copy first, then the revalidated one (§S7, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

@ProviderFor(TeamDetailSource)
final teamDetailProvider = TeamDetailSourceFamily._();

/// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
/// the cached copy first, then the revalidated one (§S7, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.
final class TeamDetailSourceProvider
    extends $StreamNotifierProvider<TeamDetailSource, SwrSnapshot<TeamDetail>> {
  /// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
  /// the cached copy first, then the revalidated one (§S7, FR-046).
  ///
  /// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
  /// would hold the state at loading for about 38 s and hide the error copy.
  TeamDetailSourceProvider._({
    required TeamDetailSourceFamily super.from,
    required int super.argument,
  }) : super(
         retry: _never,
         name: r'teamDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$teamDetailSourceHash();

  @override
  String toString() {
    return r'teamDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TeamDetailSource create() => TeamDetailSource();

  @override
  bool operator ==(Object other) {
    return other is TeamDetailSourceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$teamDetailSourceHash() => r'afe4e0252465b182eed6f929a7416fb395da0f7c';

/// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
/// the cached copy first, then the revalidated one (§S7, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

final class TeamDetailSourceFamily extends $Family
    with
        $ClassFamilyOverride<
          TeamDetailSource,
          AsyncValue<SwrSnapshot<TeamDetail>>,
          SwrSnapshot<TeamDetail>,
          Stream<SwrSnapshot<TeamDetail>>,
          int
        > {
  TeamDetailSourceFamily._()
    : super(
        retry: _never,
        name: r'teamDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
  /// the cached copy first, then the revalidated one (§S7, FR-046).
  ///
  /// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
  /// would hold the state at loading for about 38 s and hide the error copy.

  TeamDetailSourceProvider call(int teamId) =>
      TeamDetailSourceProvider._(argument: teamId, from: this);

  @override
  String toString() => r'teamDetailProvider';
}

/// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
/// the cached copy first, then the revalidated one (§S7, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

abstract class _$TeamDetailSource
    extends $StreamNotifier<SwrSnapshot<TeamDetail>> {
  late final _$args = ref.$arg as int;
  int get teamId => _$args;

  Stream<SwrSnapshot<TeamDetail>> build(int teamId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<TeamDetail>>,
              SwrSnapshot<TeamDetail>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<TeamDetail>>,
                SwrSnapshot<TeamDetail>
              >,
              AsyncValue<SwrSnapshot<TeamDetail>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
