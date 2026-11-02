// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zone_holder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one holder (keepAlive: the database reads it for its whole life).

@ProviderFor(zoneHolder)
final zoneHolderProvider = ZoneHolderProvider._();

/// The one holder (keepAlive: the database reads it for its whole life).

final class ZoneHolderProvider
    extends $FunctionalProvider<ZoneHolder, ZoneHolder, ZoneHolder>
    with $Provider<ZoneHolder> {
  /// The one holder (keepAlive: the database reads it for its whole life).
  ZoneHolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoneHolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoneHolderHash();

  @$internal
  @override
  $ProviderElement<ZoneHolder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ZoneHolder create(Ref ref) {
    return zoneHolder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ZoneHolder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ZoneHolder>(value),
    );
  }
}

String _$zoneHolderHash() => r'35ac19e0cbb890b24b1625b4cc71425f3c20e779';
