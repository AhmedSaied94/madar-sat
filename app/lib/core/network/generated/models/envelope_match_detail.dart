// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'match_detail.dart';

part 'envelope_match_detail.freezed.dart';
part 'envelope_match_detail.g.dart';

@Freezed()
abstract class EnvelopeMatchDetail with _$EnvelopeMatchDetail {
  const factory EnvelopeMatchDetail({
    required MatchDetail? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeMatchDetail;
  
  factory EnvelopeMatchDetail.fromJson(Map<String, Object?> json) => _$EnvelopeMatchDetailFromJson(json);
}
