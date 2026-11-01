// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope_list_channel_carriage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnvelopeListChannelCarriage _$EnvelopeListChannelCarriageFromJson(
  Map<String, dynamic> json,
) => _EnvelopeListChannelCarriage(
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => ChannelCarriage.fromJson(e as Map<String, dynamic>))
      .toList(),
  error: json['error'] == null
      ? null
      : ErrorBody.fromJson(json['error'] as Map<String, dynamic>),
  meta: json['meta'],
  success: json['success'] as bool,
);

Map<String, dynamic> _$EnvelopeListChannelCarriageToJson(
  _EnvelopeListChannelCarriage instance,
) => <String, dynamic>{
  'data': ?instance.data,
  'error': ?instance.error,
  'meta': ?instance.meta,
  'success': instance.success,
};
