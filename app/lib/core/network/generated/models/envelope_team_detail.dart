// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'team_detail.dart';

part 'envelope_team_detail.freezed.dart';
part 'envelope_team_detail.g.dart';

@Freezed()
abstract class EnvelopeTeamDetail with _$EnvelopeTeamDetail {
  const factory EnvelopeTeamDetail({
    required TeamDetail? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeTeamDetail;
  
  factory EnvelopeTeamDetail.fromJson(Map<String, Object?> json) => _$EnvelopeTeamDetailFromJson(json);
}
