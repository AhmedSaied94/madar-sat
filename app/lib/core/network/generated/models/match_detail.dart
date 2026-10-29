// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'broadcast.dart';
import 'broadcast_entry.dart';
import 'carriage_entry.dart';
import 'commentator_ref.dart';
import 'competition_ref.dart';
import 'period.dart';
import 'platform_group.dart';
import 'score.dart';
import 'sport.dart';
import 'status.dart';
import 'team_ref.dart';

part 'match_detail.freezed.dart';
part 'match_detail.g.dart';

@Freezed()
abstract class MatchDetail with _$MatchDetail {
  const factory MatchDetail({
    required TeamRef away,
    required Broadcast broadcast,
    required List<BroadcastEntry> broadcasts,
    required List<CarriageEntry> carriages,
    required CommentatorRef? commentator,
    required CompetitionRef competition,
    required bool estimated,
    required List<dynamic> events,
    @JsonKey(name: 'feed_id')
    required int? feedId,
    required TeamRef home,
    required int id,
    @JsonKey(name: 'kickoff_at')
    required DateTime? kickoffAt,
    required dynamic lineups,
    @JsonKey(name: 'local_broadcaster_eg')
    required String? localBroadcasterEg,
    @JsonKey(name: 'match_date')
    required DateTime matchDate,
    required String? minute,
    required Period? period,
    required List<PlatformGroup> platforms,
    required Score? score,
    required Sport sport,
    required String? stadium,
    required Status status,
    @JsonKey(name: 'status_label')
    required String? statusLabel,
    @JsonKey(name: 'time_tbd')
    required bool timeTbd,
    @JsonKey(name: 'updated_at')
    required DateTime updatedAt,
  }) = _MatchDetail;
  
  factory MatchDetail.fromJson(Map<String, Object?> json) => _$MatchDetailFromJson(json);
}
