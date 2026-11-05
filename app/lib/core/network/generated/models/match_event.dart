// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'match_event_side.dart';
import 'match_event_type.dart';

part 'match_event.freezed.dart';
part 'match_event.g.dart';

/// A structured fact from the feed. Goal-type events are absent while their score is unconfirmed.
@Freezed()
abstract class MatchEvent with _$MatchEvent {
  const factory MatchEvent({
    required String minute,
    required String? player,
    required MatchEventSide side,
    required MatchEventType type,
  }) = _MatchEvent;
  
  factory MatchEvent.fromJson(Map<String, Object?> json) => _$MatchEventFromJson(json);
}
