// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_entry.freezed.dart';
part 'platform_entry.g.dart';

@Freezed()
abstract class PlatformEntry with _$PlatformEntry {
  const factory PlatformEntry({
    @JsonKey(name: 'channel_id')
    required int channelId,
    required String? country,
    required String? logo,
    required String name,
  }) = _PlatformEntry;
  
  factory PlatformEntry.fromJson(Map<String, Object?> json) => _$PlatformEntryFromJson(json);
}
