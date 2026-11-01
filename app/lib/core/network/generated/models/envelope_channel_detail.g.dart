// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_channel_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeChannelDetail _$EnvelopeChannelDetailFromJson(
  Map<String, dynamic> json,
) => _EnvelopeChannelDetail(
  data: json['data'] == null
      ? null
      : ChannelDetail.fromJson(json['data'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeChannelDetailToJson(
  _EnvelopeChannelDetail instance,
) => <String, dynamic>{
  'data': ?instance.data,
  'error': ?instance.error,
  'meta': ?instance.meta,
  'success': instance.success,
};
