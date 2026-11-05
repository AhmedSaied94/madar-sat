// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'match_summary.dart';
import 'rights_holder_ref.dart';
import 'sport.dart';

part 'competition_detail.freezed.dart';
part 'competition_detail.g.dart';

@Freezed()
abstract class CompetitionDetail with _$CompetitionDetail {
  const factory CompetitionDetail({
    required int id,
    required String? logo,
    required String name,
    required int? priority,
    required List<MatchSummary> recent,
    @JsonKey(name: 'rights_holders')
    required List<RightsHolderRef> rightsHolders,
    required Sport sport,
    required List<MatchSummary> upcoming,
  }) = _CompetitionDetail;
  
  factory CompetitionDetail.fromJson(Map<String, Object?> json) => _$CompetitionDetailFromJson(json);
}
