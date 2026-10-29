// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Broadcast _$BroadcastFromJson(Map<String, dynamic> json) => _Broadcast(
  channelCount: (json['channel_count'] as num).toInt(),
  hasFree: json['has_free'] as bool,
  headline: (json['headline'] as List<dynamic>)
      .map((e) => HeadlineEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$BroadcastToJson(_Broadcast instance) =>
    <String, dynamic>{
      'channel_count': instance.channelCount,
      'has_free': instance.hasFree,
      'headline': instance.headline,
    };
