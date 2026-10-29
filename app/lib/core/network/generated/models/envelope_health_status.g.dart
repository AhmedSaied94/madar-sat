// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_health_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeHealthStatus _$EnvelopeHealthStatusFromJson(
  Map<String, dynamic> json,
) => _EnvelopeHealthStatus(
  data: json['data'] == null
      ? null
      : HealthStatus.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeHealthStatusToJson(
  _EnvelopeHealthStatus instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
