// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'broadcast.dart';
import 'commentator_ref.dart';
import 'competition_ref.dart';
import 'period.dart';
import 'score.dart';
import 'sport.dart';
import 'status.dart';
import 'team_ref.dart';

part 'match_summary.freezed.dart';
part 'match_summary.g.dart';

@Freezed()
abstract class MatchSummary with _$MatchSummary {
  const factory MatchSummary({
    required TeamRef away,
    required Broadcast broadcast,
    required CommentatorRef? commentator,
    required CompetitionRef competition,
    required bool estimated,
    required TeamRef home,
    required int id,
    @JsonKey(name: 'kickoff_at')
    required DateTime? kickoffAt,
    @JsonKey(name: 'match_date')
    required DateTime matchDate,
    required String? minute,
    required Period? period,
    required Score? score,
    required Sport sport,
    required Status status,
    @JsonKey(name: 'status_label')
    required String? statusLabel,
    @JsonKey(name: 'time_tbd')
    required bool timeTbd,
    @JsonKey(name: 'updated_at')
    required DateTime updatedAt,
  }) = _MatchSummary;
  
  factory MatchSummary.fromJson(Map<String, Object?> json) => _$MatchSummaryFromJson(json);
}
