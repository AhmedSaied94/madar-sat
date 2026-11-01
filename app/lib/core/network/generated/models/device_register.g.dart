// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_register.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceRegister _$DeviceRegisterFromJson(Map<String, dynamic> json) =>
    _DeviceRegister(
      installId: json['install_id'] as String,
      platform: DeviceRegisterPlatform.fromJson(json['platform'] as String),
    );

Map<String, dynamic> _$DeviceRegisterToJson(_DeviceRegister instance) =>
    <String, dynamic>{
      'install_id': instance.installId,
      'platform': _$DeviceRegisterPlatformEnumMap[instance.platform]!,
    };

const _$DeviceRegisterPlatformEnumMap = {
  DeviceRegisterPlatform.android: 'android',
  DeviceRegisterPlatform.ios: 'ios',
  DeviceRegisterPlatform.web: 'web',
  DeviceRegisterPlatform.$unknown: r'$unknown',
};
