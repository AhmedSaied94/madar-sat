// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_registered.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceRegistered _$DeviceRegisteredFromJson(Map<String, dynamic> json) =>
    _DeviceRegistered(
      deviceId: (json['device_id'] as num).toInt(),
      deviceToken: json['device_token'] as String,
    );

Map<String, dynamic> _$DeviceRegisteredToJson(_DeviceRegistered instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'device_token': instance.deviceToken,
    };
