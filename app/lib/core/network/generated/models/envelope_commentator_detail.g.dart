// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_commentator_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeCommentatorDetail _$EnvelopeCommentatorDetailFromJson(
  Map<String, dynamic> json,
) => _EnvelopeCommentatorDetail(
  data: json['data'] == null
      ? null
      : CommentatorDetail.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeCommentatorDetailToJson(
  _EnvelopeCommentatorDetail instance,
) => <String, dynamic>{
  'data': ?instance.data,
  'error': ?instance.error,
  'meta': ?instance.meta,
  'success': instance.success,
};
