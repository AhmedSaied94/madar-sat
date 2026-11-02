// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'follow_set.freezed.dart';
part 'follow_set.g.dart';

/// The whole follow set: ≤ 500 ids in total, duplicates collapsed (research R5).
@Freezed()
abstract class FollowSet with _$FollowSet {
  const factory FollowSet({
    List<int>? channels,
    List<int>? commentators,
    List<int>? competitions,
    List<int>? matches,
    List<int>? teams,
  }) = _FollowSet;
  
  factory FollowSet.fromJson(Map<String, Object?> json) => _$FollowSetFromJson(json);
}
