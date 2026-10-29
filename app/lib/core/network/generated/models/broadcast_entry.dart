// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'access.dart';
import 'broadcast_entry_kind.dart';
import 'commentator_ref.dart';
import 'frequency.dart';
import 'satellite_ref.dart';

part 'broadcast_entry.freezed.dart';
part 'broadcast_entry.g.dart';

@Freezed()
abstract class BroadcastEntry with _$BroadcastEntry {
  const factory BroadcastEntry({
    required Access? access,
    @JsonKey(name: 'channel_id')
    required int? channelId,
    required List<CommentatorRef> commentators,
    required Frequency? frequency,
    required BroadcastEntryKind kind,
    required String label,
    required String? logo,
    required SatelliteRef? satellite,
  }) = _BroadcastEntry;
  
  factory BroadcastEntry.fromJson(Map<String, Object?> json) => _$BroadcastEntryFromJson(json);
}
