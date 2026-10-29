// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'period.dart';
import 'score.dart';
import 'status.dart';

part 'live_state.freezed.dart';
part 'live_state.g.dart';

@Freezed()
abstract class LiveState with _$LiveState {
  const factory LiveState({
    required bool estimated,
    @JsonKey(name: 'match_id')
    required int matchId,
    required String? minute,
    required Period? period,
    required Score? score,
    required Status status,
    @JsonKey(name: 'status_label')
    required String? statusLabel,
    @JsonKey(name: 'status_updated_at')
    required DateTime? statusUpdatedAt,
  }) = _LiveState;
  
  factory LiveState.fromJson(Map<String, Object?> json) => _$LiveStateFromJson(json);
}
