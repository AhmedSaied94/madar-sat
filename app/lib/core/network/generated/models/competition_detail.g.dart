// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'competition_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CompetitionDetail _$CompetitionDetailFromJson(Map<String, dynamic> json) =>
    _CompetitionDetail(
      id: (json['id'] as num).toInt(),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      priority: (json['priority'] as num?)?.toInt(),
      recent: (json['recent'] as List<dynamic>)
          .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      rightsHolders: (json['rights_holders'] as List<dynamic>)
          .map((e) => RightsHolderRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      sport: Sport.fromJson(json['sport'] as String),
      upcoming: (json['upcoming'] as List<dynamic>)
          .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CompetitionDetailToJson(_CompetitionDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'logo': ?instance.logo,
      'name': instance.name,
      'priority': ?instance.priority,
      'recent': instance.recent,
      'rights_holders': instance.rightsHolders,
      'sport': _$SportEnumMap[instance.sport]!,
      'upcoming': instance.upcoming,
    };

const _$SportEnumMap = {
  Sport.football: 'football',
  Sport.basketball: 'basketball',
  Sport.handball: 'handball',
  Sport.volleyball: 'volleyball',
  Sport.tennis: 'tennis',
  Sport.$unknown: r'$unknown',
};
