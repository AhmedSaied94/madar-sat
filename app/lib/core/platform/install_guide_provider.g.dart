// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'install_guide_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The install guide this platform uses: the web's standalone detection, or "installed" on
/// a native build.

@ProviderFor(installGuide)
final installGuideProvider = InstallGuideProvider._();

/// The install guide this platform uses: the web's standalone detection, or "installed" on
/// a native build.

final class InstallGuideProvider
    extends $FunctionalProvider<InstallGuide, InstallGuide, InstallGuide>
    with $Provider<InstallGuide> {
  /// The install guide this platform uses: the web's standalone detection, or "installed" on
  /// a native build.
  InstallGuideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installGuideProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installGuideHash();

  @$internal
  @override
  $ProviderElement<InstallGuide> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InstallGuide create(Ref ref) {
    return installGuide(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstallGuide value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstallGuide>(value),
    );
  }
}

String _$installGuideHash() => r'2ab2a504baca2337030a64eb238a8029cef167fd';
