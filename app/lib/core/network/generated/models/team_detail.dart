// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'match_summary.dart';
import 'named_ref.dart';
import 'primary_competition_ref.dart';
import 'sport.dart';

part 'team_detail.freezed.dart';
part 'team_detail.g.dart';

@Freezed()
abstract class TeamDetail with _$TeamDetail {
  const factory TeamDetail({
    required List<NamedRef> competitions,
    required String? country,
    required int id,
    required String? logo,
    required String name,
    @JsonKey(name: 'primary_competition')
    required PrimaryCompetitionRef? primaryCompetition,
    required List<MatchSummary> recent,
    required Sport sport,
    required String? stadium,
    required List<MatchSummary> upcoming,
  }) = _TeamDetail;
  
  factory TeamDetail.fromJson(Map<String, Object?> json) => _$TeamDetailFromJson(json);
}
