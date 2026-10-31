// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frequencies_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The text typed in S5.1's search field.

@ProviderFor(SatelliteSearch)
final satelliteSearchProvider = SatelliteSearchProvider._();

/// The text typed in S5.1's search field.
final class SatelliteSearchProvider
    extends $NotifierProvider<SatelliteSearch, String> {
  /// The text typed in S5.1's search field.
  SatelliteSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'satelliteSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$satelliteSearchHash();

  @$internal
  @override
  SatelliteSearch create() => SatelliteSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$satelliteSearchHash() => r'4e9de452ba0693ca47770f6219df21339d33df25';

/// The text typed in S5.1's search field.

abstract class _$SatelliteSearch extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
/// satellite's search or open row never leaks into another's.

@ProviderFor(ChannelSearch)
final channelSearchProvider = ChannelSearchFamily._();

/// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
/// satellite's search or open row never leaks into another's.
final class ChannelSearchProvider
    extends $NotifierProvider<ChannelSearch, String> {
  /// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
  /// satellite's search or open row never leaks into another's.
  ChannelSearchProvider._({
    required ChannelSearchFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'channelSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$channelSearchHash();

  @override
  String toString() {
    return r'channelSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChannelSearch create() => ChannelSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChannelSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$channelSearchHash() => r'09ff90e69a1a79043e5d222ed70b53d5d594937f';

/// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
/// satellite's search or open row never leaks into another's.

final class ChannelSearchFamily extends $Family
    with $ClassFamilyOverride<ChannelSearch, String, String, String, int> {
  ChannelSearchFamily._()
    : super(
        retry: null,
        name: r'channelSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
  /// satellite's search or open row never leaks into another's.

  ChannelSearchProvider call(int satelliteId) =>
      ChannelSearchProvider._(argument: satelliteId, from: this);

  @override
  String toString() => r'channelSearchProvider';
}

/// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
/// satellite's search or open row never leaks into another's.

abstract class _$ChannelSearch extends $Notifier<String> {
  late final _$args = ref.$arg as int;
  int get satelliteId => _$args;

  String build(int satelliteId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The tab S5.2 is on. The page view and the segmented control both write it.

@ProviderFor(SelectedCategory)
final selectedCategoryProvider = SelectedCategoryFamily._();

/// The tab S5.2 is on. The page view and the segmented control both write it.
final class SelectedCategoryProvider
    extends $NotifierProvider<SelectedCategory, Category> {
  /// The tab S5.2 is on. The page view and the segmented control both write it.
  SelectedCategoryProvider._({
    required SelectedCategoryFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'selectedCategoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$selectedCategoryHash();

  @override
  String toString() {
    return r'selectedCategoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SelectedCategory create() => SelectedCategory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Category value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Category>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SelectedCategoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$selectedCategoryHash() => r'3ba471cb1ba4b2d967046be29cc821a1af360ffb';

/// The tab S5.2 is on. The page view and the segmented control both write it.

final class SelectedCategoryFamily extends $Family
    with
        $ClassFamilyOverride<
          SelectedCategory,
          Category,
          Category,
          Category,
          int
        > {
  SelectedCategoryFamily._()
    : super(
        retry: null,
        name: r'selectedCategoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The tab S5.2 is on. The page view and the segmented control both write it.

  SelectedCategoryProvider call(int satelliteId) =>
      SelectedCategoryProvider._(argument: satelliteId, from: this);

  @override
  String toString() => r'selectedCategoryProvider';
}

/// The tab S5.2 is on. The page view and the segmented control both write it.

abstract class _$SelectedCategory extends $Notifier<Category> {
  late final _$args = ref.$arg as int;
  int get satelliteId => _$args;

  Category build(int satelliteId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Category, Category>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Category, Category>,
              Category,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The channel whose row is open, if any. One at a time (CarriageRow README).

@ProviderFor(ExpandedChannel)
final expandedChannelProvider = ExpandedChannelFamily._();

/// The channel whose row is open, if any. One at a time (CarriageRow README).
final class ExpandedChannelProvider
    extends $NotifierProvider<ExpandedChannel, int?> {
  /// The channel whose row is open, if any. One at a time (CarriageRow README).
  ExpandedChannelProvider._({
    required ExpandedChannelFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'expandedChannelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expandedChannelHash();

  @override
  String toString() {
    return r'expandedChannelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ExpandedChannel create() => ExpandedChannel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExpandedChannelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expandedChannelHash() => r'274f2f36e849b703b6edf2e12d99c676585cc2ff';

/// The channel whose row is open, if any. One at a time (CarriageRow README).

final class ExpandedChannelFamily extends $Family
    with $ClassFamilyOverride<ExpandedChannel, int?, int?, int?, int> {
  ExpandedChannelFamily._()
    : super(
        retry: null,
        name: r'expandedChannelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The channel whose row is open, if any. One at a time (CarriageRow README).

  ExpandedChannelProvider call(int satelliteId) =>
      ExpandedChannelProvider._(argument: satelliteId, from: this);

  @override
  String toString() => r'expandedChannelProvider';
}

/// The channel whose row is open, if any. One at a time (CarriageRow README).

abstract class _$ExpandedChannel extends $Notifier<int?> {
  late final _$args = ref.$arg as int;
  int get satelliteId => _$args;

  int? build(int satelliteId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
