// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lineup_side.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineupSide _$LineupSideFromJson(Map<String, dynamic> json) => _LineupSide(
  formation: json['formation'] as String?,
  players: (json['players'] as List<dynamic>)
      .map((e) => LineupPlayer.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LineupSideToJson(_LineupSide instance) =>
    <String, dynamic>{
      'formation': ?instance.formation,
      'players': instance.players,
    };
