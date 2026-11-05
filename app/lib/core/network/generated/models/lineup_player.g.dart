// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lineup_player.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineupPlayer _$LineupPlayerFromJson(Map<String, dynamic> json) =>
    _LineupPlayer(
      isStarter: json['is_starter'] as bool,
      name: json['name'] as String,
      number: (json['number'] as num?)?.toInt(),
      position: json['position'] as String?,
    );

Map<String, dynamic> _$LineupPlayerToJson(_LineupPlayer instance) =>
    <String, dynamic>{
      'is_starter': instance.isStarter,
      'name': instance.name,
      'number': ?instance.number,
      'position': ?instance.position,
    };
