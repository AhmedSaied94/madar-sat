// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
/// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
///
/// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

@ProviderFor(ChannelDetailSource)
final channelDetailProvider = ChannelDetailSourceFamily._();

/// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
/// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
///
/// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.
final class ChannelDetailSourceProvider
    extends
        $StreamNotifierProvider<
          ChannelDetailSource,
          SwrSnapshot<ChannelDetail>
        > {
  /// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
  /// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
  ///
  /// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
  /// would hold the state at loading for about 38 s and hide the error copy.
  ChannelDetailSourceProvider._({
    required ChannelDetailSourceFamily super.from,
    required int super.argument,
  }) : super(
         retry: _never,
         name: r'channelDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$channelDetailSourceHash();

  @override
  String toString() {
    return r'channelDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChannelDetailSource create() => ChannelDetailSource();

  @override
  bool operator ==(Object other) {
    return other is ChannelDetailSourceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$channelDetailSourceHash() =>
    r'666636fa98be6c0bc004b974d6a168eecc34dbd2';

/// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
/// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
///
/// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

final class ChannelDetailSourceFamily extends $Family
    with
        $ClassFamilyOverride<
          ChannelDetailSource,
          AsyncValue<SwrSnapshot<ChannelDetail>>,
          SwrSnapshot<ChannelDetail>,
          Stream<SwrSnapshot<ChannelDetail>>,
          int
        > {
  ChannelDetailSourceFamily._()
    : super(
        retry: _never,
        name: r'channelDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
  /// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
  ///
  /// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
  /// would hold the state at loading for about 38 s and hide the error copy.

  ChannelDetailSourceProvider call(int channelId) =>
      ChannelDetailSourceProvider._(argument: channelId, from: this);

  @override
  String toString() => r'channelDetailProvider';
}

/// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
/// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
///
/// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.

abstract class _$ChannelDetailSource
    extends $StreamNotifier<SwrSnapshot<ChannelDetail>> {
  late final _$args = ref.$arg as int;
  int get channelId => _$args;

  Stream<SwrSnapshot<ChannelDetail>> build(int channelId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<ChannelDetail>>,
              SwrSnapshot<ChannelDetail>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<ChannelDetail>>,
                SwrSnapshot<ChannelDetail>
              >,
              AsyncValue<SwrSnapshot<ChannelDetail>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
