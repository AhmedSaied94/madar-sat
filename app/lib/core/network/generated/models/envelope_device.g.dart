// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeDevice _$EnvelopeDeviceFromJson(Map<String, dynamic> json) =>
    _EnvelopeDevice(
      data: json['data'] == null
          ? null
          : Device.fromJson(json['data'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'],
      success: json['success'] as bool,
    );

Map<String, dynamic> _$EnvelopeDeviceToJson(_EnvelopeDevice instance) =>
    <String, dynamic>{
      'data': instance.data,
      'error': instance.error,
      'meta': instance.meta,
      'success': instance.success,
    };
