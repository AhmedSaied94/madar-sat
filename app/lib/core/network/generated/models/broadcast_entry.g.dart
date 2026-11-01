// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BroadcastEntry _$BroadcastEntryFromJson(Map<String, dynamic> json) =>
    _BroadcastEntry(
      access: json['access'] == null
          ? null
          : Access.fromJson(json['access'] as String),
      channelId: (json['channel_id'] as num?)?.toInt(),
      commentators: (json['commentators'] as List<dynamic>)
          .map((e) => CommentatorRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      frequency: json['frequency'] == null
          ? null
          : Frequency.fromJson(json['frequency'] as Map<String, dynamic>),
      kind: BroadcastEntryKind.fromJson(json['kind'] as String),
      label: json['label'] as String,
      logo: json['logo'] as String?,
      satellite: json['satellite'] == null
          ? null
          : SatelliteRef.fromJson(json['satellite'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BroadcastEntryToJson(_BroadcastEntry instance) =>
    <String, dynamic>{
      'access': ?_$AccessEnumMap[instance.access],
      'channel_id': ?instance.channelId,
      'commentators': instance.commentators,
      'frequency': ?instance.frequency,
      'kind': _$BroadcastEntryKindEnumMap[instance.kind]!,
      'label': instance.label,
      'logo': ?instance.logo,
      'satellite': ?instance.satellite,
    };

const _$AccessEnumMap = {
  Access.free: 'free',
  Access.encrypted: 'encrypted',
  Access.$unknown: r'$unknown',
};

const _$BroadcastEntryKindEnumMap = {
  BroadcastEntryKind.custom: 'custom',
  BroadcastEntryKind.channel: 'channel',
  BroadcastEntryKind.$unknown: r'$unknown',
};
