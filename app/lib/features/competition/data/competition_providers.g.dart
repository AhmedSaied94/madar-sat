// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'competition_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /v1/competitions/{id}`, stale-while-revalidate from `cached_documents` under
/// `competition:<id>`: the cached copy first, then the revalidated one (§S8, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

@ProviderFor(CompetitionDetailSource)
final competitionDetailProvider = CompetitionDetailSourceFamily._();

/// `GET /v1/competitions/{id}`, stale-while-revalidate from `cached_documents` under
/// `competition:<id>`: the cached copy first, then the revalidated one (§S8, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.
final class CompetitionDetailSourceProvider
    extends
        $StreamNotifierProvider<
          CompetitionDetailSource,
          SwrSnapshot<CompetitionDetail>
        > {
  /// `GET /v1/competitions/{id}`, stale-while-revalidate from `cached_documents` under
  /// `competition:<id>`: the cached copy first, then the revalidated one (§S8, FR-046).
  ///
  /// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
  /// would hold the state at loading for about 38 s and hide the error copy.
  CompetitionDetailSourceProvider._({
    required CompetitionDetailSourceFamily super.from,
    required int super.argument,
  }) : super(
         retry: _never,
         name: r'competitionDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$competitionDetailSourceHash();

  @override
  String toString() {
    return r'competitionDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CompetitionDetailSource create() => CompetitionDetailSource();

  @override
  bool operator ==(Object other) {
    return other is CompetitionDetailSourceProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$competitionDetailSourceHash() =>
    r'a8b4672015dbca79588ecb4b5e69983971ae4dd6';

/// `GET /v1/competitions/{id}`, stale-while-revalidate from `cached_documents` under
/// `competition:<id>`: the cached copy first, then the revalidated one (§S8, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

final class CompetitionDetailSourceFamily extends $Family
    with
        $ClassFamilyOverride<
          CompetitionDetailSource,
          AsyncValue<SwrSnapshot<CompetitionDetail>>,
          SwrSnapshot<CompetitionDetail>,
          Stream<SwrSnapshot<CompetitionDetail>>,
          int
        > {
  CompetitionDetailSourceFamily._()
    : super(
        retry: _never,
        name: r'competitionDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /v1/competitions/{id}`, stale-while-revalidate from `cached_documents` under
  /// `competition:<id>`: the cached copy first, then the revalidated one (§S8, FR-046).
  ///
  /// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
  /// would hold the state at loading for about 38 s and hide the error copy.

  CompetitionDetailSourceProvider call(int competitionId) =>
      CompetitionDetailSourceProvider._(argument: competitionId, from: this);

  @override
  String toString() => r'competitionDetailProvider';
}

/// `GET /v1/competitions/{id}`, stale-while-revalidate from `cached_documents` under
/// `competition:<id>`: the cached copy first, then the revalidated one (§S8, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

abstract class _$CompetitionDetailSource
    extends $StreamNotifier<SwrSnapshot<CompetitionDetail>> {
  late final _$args = ref.$arg as int;
  int get competitionId => _$args;

  Stream<SwrSnapshot<CompetitionDetail>> build(int competitionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<CompetitionDetail>>,
              SwrSnapshot<CompetitionDetail>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<CompetitionDetail>>,
                SwrSnapshot<CompetitionDetail>
              >,
              AsyncValue<SwrSnapshot<CompetitionDetail>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
