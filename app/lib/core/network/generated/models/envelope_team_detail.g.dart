// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_team_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeTeamDetail _$EnvelopeTeamDetailFromJson(Map<String, dynamic> json) =>
    _EnvelopeTeamDetail(
      data: json['data'] == null
          ? null
          : TeamDetail.fromJson(json['data'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'],
      success: json['success'] as bool,
    );

Map<String, dynamic> _$EnvelopeTeamDetailToJson(_EnvelopeTeamDetail instance) =>
    <String, dynamic>{
      'data': instance.data,
      'error': instance.error,
      'meta': instance.meta,
      'success': instance.success,
    };
