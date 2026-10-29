// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'platform_entry.dart';

part 'platform_group.freezed.dart';
part 'platform_group.g.dart';

@Freezed()
abstract class PlatformGroup with _$PlatformGroup {
  const factory PlatformGroup({
    required List<PlatformEntry> items,
    required String region,
  }) = _PlatformGroup;
  
  factory PlatformGroup.fromJson(Map<String, Object?> json) => _$PlatformGroupFromJson(json);
}
