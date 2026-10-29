// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'competition_detail.dart';
import 'error_body.dart';

part 'envelope_competition_detail.freezed.dart';
part 'envelope_competition_detail.g.dart';

@Freezed()
abstract class EnvelopeCompetitionDetail with _$EnvelopeCompetitionDetail {
  const factory EnvelopeCompetitionDetail({
    required CompetitionDetail? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeCompetitionDetail;
  
  factory EnvelopeCompetitionDetail.fromJson(Map<String, Object?> json) => _$EnvelopeCompetitionDetailFromJson(json);
}
