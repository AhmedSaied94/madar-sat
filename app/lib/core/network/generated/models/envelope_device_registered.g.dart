// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_device_registered.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeDeviceRegistered _$EnvelopeDeviceRegisteredFromJson(
  Map<String, dynamic> json,
) => _EnvelopeDeviceRegistered(
  data: json['data'] == null
      ? null
      : DeviceRegistered.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeDeviceRegisteredToJson(
  _EnvelopeDeviceRegistered instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
