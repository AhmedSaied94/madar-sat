// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_lineups.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatchLineups _$MatchLineupsFromJson(Map<String, dynamic> json) =>
    _MatchLineups(
      away: json['away'] == null
          ? null
          : LineupSide.fromJson(json['away'] as Map<String, dynamic>),
      home: json['home'] == null
          ? null
          : LineupSide.fromJson(json['home'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MatchLineupsToJson(_MatchLineups instance) =>
    <String, dynamic>{'away': ?instance.away, 'home': ?instance.home};
