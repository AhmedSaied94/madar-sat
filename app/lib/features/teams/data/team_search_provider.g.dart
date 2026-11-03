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
///
/// A failure is an [ApiFailure] carrying the envelope's `error.code`, so S1.2 can show its
/// copy, and there is no automatic retry: the error state and «إعادة المحاولة» show at once
/// (M-T045-3).

@ProviderFor(teamSearch)
final teamSearchProvider = TeamSearchFamily._();

/// `GET /v1/teams?q=` for S1.2's picker (D1's search).
///
/// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
/// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
/// are the minimum, because one letter matches half the database.
///
/// A failure is an [ApiFailure] carrying the envelope's `error.code`, so S1.2 can show its
/// copy, and there is no automatic retry: the error state and «إعادة المحاولة» show at once
/// (M-T045-3).

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
  ///
  /// A failure is an [ApiFailure] carrying the envelope's `error.code`, so S1.2 can show its
  /// copy, and there is no automatic retry: the error state and «إعادة المحاولة» show at once
  /// (M-T045-3).
  TeamSearchProvider._({
    required TeamSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: _never,
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

String _$teamSearchHash() => r'47079ffd77f4037d359ca08c63eec52a362fb60d';

/// `GET /v1/teams?q=` for S1.2's picker (D1's search).
///
/// The query goes through [normalizeSearch], the app's copy of the server's `ar_normalize`,
/// so «الأهلي» and «الاهلي» ask the same question and get the same teams; two characters
/// are the minimum, because one letter matches half the database.
///
/// A failure is an [ApiFailure] carrying the envelope's `error.code`, so S1.2 can show its
/// copy, and there is no automatic retry: the error state and «إعادة المحاولة» show at once
/// (M-T045-3).

final class TeamSearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TeamSearchItem>>, String> {
  TeamSearchFamily._()
    : super(
        retry: _never,
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
  ///
  /// A failure is an [ApiFailure] carrying the envelope's `error.code`, so S1.2 can show its
  /// copy, and there is no automatic retry: the error state and «إعادة المحاولة» show at once
  /// (M-T045-3).

  TeamSearchProvider call(String query) =>
      TeamSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'teamSearchProvider';
}
