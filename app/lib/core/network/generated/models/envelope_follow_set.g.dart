// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_follow_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeFollowSet _$EnvelopeFollowSetFromJson(Map<String, dynamic> json) =>
    _EnvelopeFollowSet(
      data: json['data'] == null
          ? null
          : FollowSet.fromJson(json['data'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'],
      success: json['success'] as bool,
    );

Map<String, dynamic> _$EnvelopeFollowSetToJson(_EnvelopeFollowSet instance) =>
    <String, dynamic>{
      'data': instance.data,
      'error': instance.error,
      'meta': instance.meta,
      'success': instance.success,
    };
