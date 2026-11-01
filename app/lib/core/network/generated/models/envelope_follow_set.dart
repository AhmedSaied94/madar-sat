// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'follow_set.dart';

part 'envelope_follow_set.freezed.dart';
part 'envelope_follow_set.g.dart';

@Freezed()
abstract class EnvelopeFollowSet with _$EnvelopeFollowSet {
  const factory EnvelopeFollowSet({
    required FollowSet? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeFollowSet;
  
  factory EnvelopeFollowSet.fromJson(Map<String, Object?> json) => _$EnvelopeFollowSetFromJson(json);
}
