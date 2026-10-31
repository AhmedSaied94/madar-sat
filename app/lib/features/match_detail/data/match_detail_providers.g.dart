// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_detail_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
/// cached copy first, then the revalidated one.
///
/// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
/// Riverpod would hold the state at loading for about 38 s, hiding the error copy.

@ProviderFor(MatchDetailSource)
final matchDetailProvider = MatchDetailSourceFamily._();

/// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
/// cached copy first, then the revalidated one.
///
/// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
/// Riverpod would hold the state at loading for about 38 s, hiding the error copy.
final class MatchDetailSourceProvider
    extends
        $StreamNotifierProvider<MatchDetailSource, SwrSnapshot<MatchDetail>> {
  /// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
  /// cached copy first, then the revalidated one.
  ///
  /// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
  /// Riverpod would hold the state at loading for about 38 s, hiding the error copy.
  MatchDetailSourceProvider._({
    required MatchDetailSourceFamily super.from,
    required int super.argument,
  }) : super(
         retry: _never,
         name: r'matchDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$matchDetailSourceHash();

  @override
  String toString() {
    return r'matchDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MatchDetailSource create() => MatchDetailSource();

  @override
  bool operator ==(Object other) {
    return other is MatchDetailSourceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$matchDetailSourceHash() => r'0ceabf9cef2509cec769a4c03396374736d1689c';

/// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
/// cached copy first, then the revalidated one.
///
/// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
/// Riverpod would hold the state at loading for about 38 s, hiding the error copy.

final class MatchDetailSourceFamily extends $Family
    with
        $ClassFamilyOverride<
          MatchDetailSource,
          AsyncValue<SwrSnapshot<MatchDetail>>,
          SwrSnapshot<MatchDetail>,
          Stream<SwrSnapshot<MatchDetail>>,
          int
        > {
  MatchDetailSourceFamily._()
    : super(
        retry: _never,
        name: r'matchDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
  /// cached copy first, then the revalidated one.
  ///
  /// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
  /// Riverpod would hold the state at loading for about 38 s, hiding the error copy.

  MatchDetailSourceProvider call(int matchId) =>
      MatchDetailSourceProvider._(argument: matchId, from: this);

  @override
  String toString() => r'matchDetailProvider';
}

/// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
/// cached copy first, then the revalidated one.
///
/// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
/// Riverpod would hold the state at loading for about 38 s, hiding the error copy.

abstract class _$MatchDetailSource
    extends $StreamNotifier<SwrSnapshot<MatchDetail>> {
  late final _$args = ref.$arg as int;
  int get matchId => _$args;

  Stream<SwrSnapshot<MatchDetail>> build(int matchId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<MatchDetail>>,
              SwrSnapshot<MatchDetail>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<MatchDetail>>,
                SwrSnapshot<MatchDetail>
              >,
              AsyncValue<SwrSnapshot<MatchDetail>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The reception video of each satellite by id, from the catalogue (`/v1/satellites`).
///
/// A satellite with no link, or with one that is not an `https` address, has no entry, so
/// its carriages have no reception action. Empty until the catalogue has loaded; the
/// channels never wait for it.

@ProviderFor(receptionUrls)
final receptionUrlsProvider = ReceptionUrlsProvider._();

/// The reception video of each satellite by id, from the catalogue (`/v1/satellites`).
///
/// A satellite with no link, or with one that is not an `https` address, has no entry, so
/// its carriages have no reception action. Empty until the catalogue has loaded; the
/// channels never wait for it.

final class ReceptionUrlsProvider
    extends $FunctionalProvider<Map<int, Uri>, Map<int, Uri>, Map<int, Uri>>
    with $Provider<Map<int, Uri>> {
  /// The reception video of each satellite by id, from the catalogue (`/v1/satellites`).
  ///
  /// A satellite with no link, or with one that is not an `https` address, has no entry, so
  /// its carriages have no reception action. Empty until the catalogue has loaded; the
  /// channels never wait for it.
  ReceptionUrlsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receptionUrlsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receptionUrlsHash();

  @$internal
  @override
  $ProviderElement<Map<int, Uri>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<int, Uri> create(Ref ref) {
    return receptionUrls(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, Uri> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, Uri>>(value),
    );
  }
}

String _$receptionUrlsHash() => r'f3227125aefba762579b80bc721bcd7a39d1c3c2';
