// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlatformEntry _$PlatformEntryFromJson(Map<String, dynamic> json) =>
    _PlatformEntry(
      channelId: (json['channel_id'] as num).toInt(),
      country: json['country'] as String?,
      logo: json['logo'] as String?,
      name: json['name'] as String,
    );

Map<String, dynamic> _$PlatformEntryToJson(_PlatformEntry instance) =>
    <String, dynamic>{
      'channel_id': instance.channelId,
      'country': instance.country,
      'logo': instance.logo,
      'name': instance.name,
    };
