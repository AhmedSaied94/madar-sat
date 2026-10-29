// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_match_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeMatchDetail _$EnvelopeMatchDetailFromJson(Map<String, dynamic> json) =>
    _EnvelopeMatchDetail(
      data: json['data'] == null
          ? null
          : MatchDetail.fromJson(json['data'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'],
      success: json['success'] as bool,
    );

Map<String, dynamic> _$EnvelopeMatchDetailToJson(
  _EnvelopeMatchDetail instance,
) => <String, dynamic>{
  'data': instance.data,
  'error': instance.error,
  'meta': instance.meta,
  'success': instance.success,
};
