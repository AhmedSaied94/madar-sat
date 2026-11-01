// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ErrorEnvelope _$ErrorEnvelopeFromJson(Map<String, dynamic> json) =>
    _ErrorEnvelope(
      data: json['data'],
      error: ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'],
      success: json['success'] as bool,
    );

Map<String, dynamic> _$ErrorEnvelopeToJson(_ErrorEnvelope instance) =>
    <String, dynamic>{
      'data': ?instance.data,
      'error': instance.error,
      'meta': ?instance.meta,
      'success': instance.success,
    };
