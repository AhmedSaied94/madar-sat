// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(clipEngine)
final clipEngineProvider = ClipEngineProvider._();

final class ClipEngineProvider
    extends $FunctionalProvider<ClipEngine, ClipEngine, ClipEngine>
    with $Provider<ClipEngine> {
  ClipEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipEngineHash();

  @$internal
  @override
  $ProviderElement<ClipEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClipEngine create(Ref ref) {
    return clipEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipEngine>(value),
    );
  }
}

String _$clipEngineHash() => r'aa56cfa8af4a5d286e17e56286ec9e72881bd818';

/// The one player for the whole app (research R26): starting a clip stops the other, and a
/// clip only ever starts from a tap (web blocks anything else).

@ProviderFor(ClipController)
final clipControllerProvider = ClipControllerProvider._();

/// The one player for the whole app (research R26): starting a clip stops the other, and a
/// clip only ever starts from a tap (web blocks anything else).
final class ClipControllerProvider
    extends $NotifierProvider<ClipController, ClipState> {
  /// The one player for the whole app (research R26): starting a clip stops the other, and a
  /// clip only ever starts from a tap (web blocks anything else).
  ClipControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipControllerHash();

  @$internal
  @override
  ClipController create() => ClipController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipState>(value),
    );
  }
}

String _$clipControllerHash() => r'4bb493db6da691f9f1b6b7731433b39b775d41f2';

/// The one player for the whole app (research R26): starting a clip stops the other, and a
/// clip only ever starts from a tap (web blocks anything else).

abstract class _$ClipController extends $Notifier<ClipState> {
  ClipState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ClipState, ClipState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ClipState, ClipState>,
              ClipState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
