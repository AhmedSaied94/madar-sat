// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'headline_entry.dart';

part 'broadcast.freezed.dart';
part 'broadcast.g.dart';

@Freezed()
abstract class Broadcast with _$Broadcast {
  const factory Broadcast({
    @JsonKey(name: 'channel_count')
    required int channelCount,
    @JsonKey(name: 'has_free')
    required bool hasFree,
    required List<HeadlineEntry> headline,
  }) = _Broadcast;
  
  factory Broadcast.fromJson(Map<String, Object?> json) => _$BroadcastFromJson(json);
}
