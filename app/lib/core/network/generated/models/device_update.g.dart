// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceUpdate _$DeviceUpdateFromJson(Map<String, dynamic> json) =>
    _DeviceUpdate(
      appVersion: json['app_version'] as String?,
      locale: json['locale'] as String?,
      prefs: json['prefs'] == null
          ? null
          : NotificationPrefs.fromJson(json['prefs'] as Map<String, dynamic>),
      pushToken: json['push_token'] as String?,
      satelliteIds: (json['satellite_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      tz: json['tz'] as String?,
    );

Map<String, dynamic> _$DeviceUpdateToJson(_DeviceUpdate instance) =>
    <String, dynamic>{
      'app_version': ?instance.appVersion,
      'locale': ?instance.locale,
      'prefs': ?instance.prefs,
      'push_token': ?instance.pushToken,
      'satellite_ids': ?instance.satelliteIds,
      'tz': ?instance.tz,
    };
