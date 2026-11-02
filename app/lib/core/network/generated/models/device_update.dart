// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'notification_prefs.dart';

part 'device_update.freezed.dart';
part 'device_update.g.dart';

/// Every field optional: an omitted field is unchanged, ``null`` clears it.
@Freezed()
abstract class DeviceUpdate with _$DeviceUpdate {
  const factory DeviceUpdate({
    @JsonKey(name: 'app_version')
    String? appVersion,
    String? locale,
    NotificationPrefs? prefs,
    @JsonKey(name: 'push_token')
    String? pushToken,
    @JsonKey(name: 'satellite_ids')
    List<int>? satelliteIds,
    String? tz,
  }) = _DeviceUpdate;
  
  factory DeviceUpdate.fromJson(Map<String, Object?> json) => _$DeviceUpdateFromJson(json);
}
