// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'primary_competition_ref.dart';
import 'sport.dart';

part 'team_search_item.freezed.dart';
part 'team_search_item.g.dart';

@Freezed()
abstract class TeamSearchItem with _$TeamSearchItem {
  const factory TeamSearchItem({
    required String? country,
    required int id,
    required String? logo,
    required String name,
    @JsonKey(name: 'primary_competition')
    required PrimaryCompetitionRef? primaryCompetition,
    required Sport sport,
  }) = _TeamSearchItem;
  
  factory TeamSearchItem.fromJson(Map<String, Object?> json) => _$TeamSearchItemFromJson(json);
}
