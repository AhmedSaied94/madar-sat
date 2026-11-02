// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FollowSet _$FollowSetFromJson(Map<String, dynamic> json) => _FollowSet(
  channels: (json['channels'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  commentators: (json['commentators'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  competitions: (json['competitions'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  matches: (json['matches'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  teams: (json['teams'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$FollowSetToJson(_FollowSet instance) =>
    <String, dynamic>{
      'channels': ?instance.channels,
      'commentators': ?instance.commentators,
      'competitions': ?instance.competitions,
      'matches': ?instance.matches,
      'teams': ?instance.teams,
    };
