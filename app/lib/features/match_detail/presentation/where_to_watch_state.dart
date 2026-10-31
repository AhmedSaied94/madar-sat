import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/generated/models/carriage_entry.dart';

part 'where_to_watch_state.g.dart';

/// The ids of S3's collapsible groups.
abstract final class GroupIds {
  static const String mine = 'mine';
  static const String withoutSatellite = 'none';

  static String satellite(int id) => 'sat:$id';

  static String region(String name) => 'region:$name';
}

/// A stable key for a carriage row (what is expanded, which row a list item is).
String carriageKey(CarriageEntry entry) => '${entry.id}/${entry.satellite?.id}';

/// What the person has done to S3's "where to watch": groups opened or closed, rows
/// expanded, and the toolbar's filters. Immutable: every change is a new value.
class WhereToWatchState {
  const WhereToWatchState({
    this.groupOpen = const {},
    this.expanded = const {},
    this.freeOnly = false,
    this.query = '',
  });

  /// Groups the person opened (true) or closed (false); a group not listed is in its
  /// default state.
  final Map<String, bool> groupOpen;

  /// The [carriageKey]s of expanded rows.
  final Set<String> expanded;
  final bool freeOnly;
  final String query;

  bool get isFiltering => freeOnly || query.trim().isNotEmpty;

  /// A filter shows what it found, so every group is open while one is on. Similarly, one
  /// row is expanded at a time (CarriageRow README): opening another closes the first.
  bool isOpen(String groupId, {required bool byDefault}) =>
      isFiltering || (groupOpen[groupId] ?? byDefault);

  WhereToWatchState copyWith({
    Map<String, bool>? groupOpen,
    Set<String>? expanded,
    bool? freeOnly,
    String? query,
  }) =>
      WhereToWatchState(
        groupOpen: groupOpen ?? this.groupOpen,
        expanded: expanded ?? this.expanded,
        freeOnly: freeOnly ?? this.freeOnly,
        query: query ?? this.query,
      );
}

/// Each match's screen has its own: the family key is the match id.
@Riverpod(name: 'whereToWatchProvider')
class WhereToWatchController extends _$WhereToWatchController {
  @override
  WhereToWatchState build(int matchId) => const WhereToWatchState();

  void toggleGroup(String groupId, {required bool currentlyOpen}) {
    state = state.copyWith(groupOpen: {...state.groupOpen, groupId: !currentlyOpen});
  }

  /// One row open at a time (CarriageRow README).
  void toggleCarriage(String key) {
    final expanded = {...state.expanded};
    if (!expanded.remove(key)) expanded.add(key);
    state = state.copyWith(expanded: expanded);
  }

  void toggleFreeOnly() => state = state.copyWith(freeOnly: !state.freeOnly);

  void setQuery(String query) => state = state.copyWith(query: query);
}
