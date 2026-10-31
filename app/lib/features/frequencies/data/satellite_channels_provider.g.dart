// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'satellite_channels_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
///
/// The whole list is fetched once, and the screen filters it by category and search
/// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
/// retry: the error copy and «إعادة المحاولة» show at once.

@ProviderFor(SatelliteChannels)
final satelliteChannelsProvider = SatelliteChannelsFamily._();

/// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
///
/// The whole list is fetched once, and the screen filters it by category and search
/// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
/// retry: the error copy and «إعادة المحاولة» show at once.
final class SatelliteChannelsProvider
    extends
        $StreamNotifierProvider<
          SatelliteChannels,
          SwrSnapshot<List<ChannelCarriage>>
        > {
  /// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
  ///
  /// The whole list is fetched once, and the screen filters it by category and search
  /// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
  /// retry: the error copy and «إعادة المحاولة» show at once.
  SatelliteChannelsProvider._({
    required SatelliteChannelsFamily super.from,
    required int super.argument,
  }) : super(
         retry: _never,
         name: r'satelliteChannelsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$satelliteChannelsHash();

  @override
  String toString() {
    return r'satelliteChannelsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SatelliteChannels create() => SatelliteChannels();

  @override
  bool operator ==(Object other) {
    return other is SatelliteChannelsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$satelliteChannelsHash() => r'f9972b4d6948443201336abacea25948e09514b0';

/// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
///
/// The whole list is fetched once, and the screen filters it by category and search
/// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
/// retry: the error copy and «إعادة المحاولة» show at once.

final class SatelliteChannelsFamily extends $Family
    with
        $ClassFamilyOverride<
          SatelliteChannels,
          AsyncValue<SwrSnapshot<List<ChannelCarriage>>>,
          SwrSnapshot<List<ChannelCarriage>>,
          Stream<SwrSnapshot<List<ChannelCarriage>>>,
          int
        > {
  SatelliteChannelsFamily._()
    : super(
        retry: _never,
        name: r'satelliteChannelsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
  ///
  /// The whole list is fetched once, and the screen filters it by category and search
  /// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
  /// retry: the error copy and «إعادة المحاولة» show at once.

  SatelliteChannelsProvider call(int satelliteId) =>
      SatelliteChannelsProvider._(argument: satelliteId, from: this);

  @override
  String toString() => r'satelliteChannelsProvider';
}

/// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
///
/// The whole list is fetched once, and the screen filters it by category and search
/// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
/// retry: the error copy and «إعادة المحاولة» show at once.

abstract class _$SatelliteChannels
    extends $StreamNotifier<SwrSnapshot<List<ChannelCarriage>>> {
  late final _$args = ref.$arg as int;
  int get satelliteId => _$args;

  Stream<SwrSnapshot<List<ChannelCarriage>>> build(int satelliteId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<List<ChannelCarriage>>>,
              SwrSnapshot<List<ChannelCarriage>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<List<ChannelCarriage>>>,
                SwrSnapshot<List<ChannelCarriage>>
              >,
              AsyncValue<SwrSnapshot<List<ChannelCarriage>>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The satellite's own entry from the cached list (name, position, aids, reception video),
/// or null while the list has not loaded or when it does not hold this satellite.

@ProviderFor(satelliteById)
final satelliteByIdProvider = SatelliteByIdFamily._();

/// The satellite's own entry from the cached list (name, position, aids, reception video),
/// or null while the list has not loaded or when it does not hold this satellite.

final class SatelliteByIdProvider
    extends $FunctionalProvider<Satellite?, Satellite?, Satellite?>
    with $Provider<Satellite?> {
  /// The satellite's own entry from the cached list (name, position, aids, reception video),
  /// or null while the list has not loaded or when it does not hold this satellite.
  SatelliteByIdProvider._({
    required SatelliteByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'satelliteByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$satelliteByIdHash();

  @override
  String toString() {
    return r'satelliteByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Satellite?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Satellite? create(Ref ref) {
    final argument = this.argument as int;
    return satelliteById(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Satellite? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Satellite?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SatelliteByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$satelliteByIdHash() => r'4d3260fcdd68c4dd6b4e96c50e804eb4678f466d';

/// The satellite's own entry from the cached list (name, position, aids, reception video),
/// or null while the list has not loaded or when it does not hold this satellite.

final class SatelliteByIdFamily extends $Family
    with $FunctionalFamilyOverride<Satellite?, int> {
  SatelliteByIdFamily._()
    : super(
        retry: null,
        name: r'satelliteByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The satellite's own entry from the cached list (name, position, aids, reception video),
  /// or null while the list has not loaded or when it does not hold this satellite.

  SatelliteByIdProvider call(int satelliteId) =>
      SatelliteByIdProvider._(argument: satelliteId, from: this);

  @override
  String toString() => r'satelliteByIdProvider';
}
