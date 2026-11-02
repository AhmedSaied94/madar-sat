// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Device _$DeviceFromJson(Map<String, dynamic> json) => _Device(
  appVersion: json['app_version'] as String?,
  deviceId: (json['device_id'] as num).toInt(),
  hasPushToken: json['has_push_token'] as bool,
  locale: json['locale'] as String?,
  platform: DevicePlatform.fromJson(json['platform'] as String),
  prefs: NotificationPrefs.fromJson(json['prefs'] as Map<String, dynamic>),
  satelliteIds: (json['satellite_ids'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  tz: json['tz'] as String?,
);

Map<String, dynamic> _$DeviceToJson(_Device instance) => <String, dynamic>{
  'app_version': ?instance.appVersion,
  'device_id': instance.deviceId,
  'has_push_token': instance.hasPushToken,
  'locale': ?instance.locale,
  'platform': _$DevicePlatformEnumMap[instance.platform]!,
  'prefs': instance.prefs,
  'satellite_ids': instance.satelliteIds,
  'tz': ?instance.tz,
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.android: 'android',
  DevicePlatform.ios: 'ios',
  DevicePlatform.web: 'web',
  DevicePlatform.$unknown: r'$unknown',
};
