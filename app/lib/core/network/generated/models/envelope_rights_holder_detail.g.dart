// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_rights_holder_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeRightsHolderDetail _$EnvelopeRightsHolderDetailFromJson(
  Map<String, dynamic> json,
) => _EnvelopeRightsHolderDetail(
  data: json['data'] == null
      ? null
      : RightsHolderDetail.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeRightsHolderDetailToJson(
  _EnvelopeRightsHolderDetail instance,
) => <String, dynamic>{
  'data': ?instance.data,
  'error': ?instance.error,
  'meta': ?instance.meta,
  'success': instance.success,
};
