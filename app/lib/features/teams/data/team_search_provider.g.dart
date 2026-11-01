// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `GET /v1/teams?q=` for S1.2's picker (D1's search).
///
/// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
/// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
/// are the minimum, because one letter matches half the database.

@ProviderFor(teamSearch)
final teamSearchProvider = TeamSearchFamily._();

/// `GET /v1/teams?q=` for S1.2's picker (D1's search).
///
/// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
/// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
/// are the minimum, because one letter matches half the database.

final class TeamSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TeamSearchItem>>,
          List<TeamSearchItem>,
          FutureOr<List<TeamSearchItem>>
        >
    with
        $FutureModifier<List<TeamSearchItem>>,
        $FutureProvider<List<TeamSearchItem>> {
  /// `GET /v1/teams?q=` for S1.2's picker (D1's search).
  ///
  /// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
  /// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
  /// are the minimum, because one letter matches half the database.
  TeamSearchProvider._({
    required TeamSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'teamSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$teamSearchHash();

  @override
  String toString() {
    return r'teamSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TeamSearchItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TeamSearchItem>> create(Ref ref) {
    final argument = this.argument as String;
    return teamSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TeamSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$teamSearchHash() => r'85d6c9accb42b526a6be266d2efe4bb3f54f9605';

/// `GET /v1/teams?q=` for S1.2's picker (D1's search).
///
/// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
/// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
/// are the minimum, because one letter matches half the database.

final class TeamSearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TeamSearchItem>>, String> {
  TeamSearchFamily._()
    : super(
        retry: null,
        name: r'teamSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// `GET /v1/teams?q=` for S1.2's picker (D1's search).
  ///
  /// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
  /// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
  /// are the minimum, because one letter matches half the database.

  TeamSearchProvider call(String query) =>
      TeamSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'teamSearchProvider';
}
