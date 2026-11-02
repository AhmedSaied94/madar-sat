// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'headline_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HeadlineEntry _$HeadlineEntryFromJson(Map<String, dynamic> json) =>
    _HeadlineEntry(
      access: json['access'] == null
          ? null
          : Access.fromJson(json['access'] as String),
      channelId: (json['channel_id'] as num).toInt(),
      frequency: json['frequency'] == null
          ? null
          : Frequency.fromJson(json['frequency'] as Map<String, dynamic>),
      name: json['name'] as String,
      satellite: json['satellite'] == null
          ? null
          : SatelliteRef.fromJson(json['satellite'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HeadlineEntryToJson(_HeadlineEntry instance) =>
    <String, dynamic>{
      'access': ?_$AccessEnumMap[instance.access],
      'channel_id': instance.channelId,
      'frequency': ?instance.frequency,
      'name': instance.name,
      'satellite': ?instance.satellite,
    };

const _$AccessEnumMap = {
  Access.free: 'free',
  Access.encrypted: 'encrypted',
  Access.$unknown: r'$unknown',
};
