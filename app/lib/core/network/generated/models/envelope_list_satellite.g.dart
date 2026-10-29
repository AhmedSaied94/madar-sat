// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_satellite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListSatellite _$EnvelopeListSatelliteFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListSatellite(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => Satellite.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListSatelliteToJson(
  _EnvelopeListSatellite instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
