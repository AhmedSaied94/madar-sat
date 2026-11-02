// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_platform.dart';
import 'notification_prefs.dart';

part 'device.freezed.dart';
part 'device.g.dart';

/// What the server stores, without the token or its hash (contracts/public-devices.md).
@Freezed()
abstract class Device with _$Device {
  const factory Device({
    @JsonKey(name: 'app_version')
    required String? appVersion,
    @JsonKey(name: 'device_id')
    required int deviceId,
    @JsonKey(name: 'has_push_token')
    required bool hasPushToken,
    required String? locale,
    required DevicePlatform platform,
    required NotificationPrefs prefs,
    @JsonKey(name: 'satellite_ids')
    required List<int> satelliteIds,
    required String? tz,
  }) = _Device;
  
  factory Device.fromJson(Map<String, Object?> json) => _$DeviceFromJson(json);
}
