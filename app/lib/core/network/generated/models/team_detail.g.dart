// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamDetail _$TeamDetailFromJson(Map<String, dynamic> json) => _TeamDetail(
  competitions: (json['competitions'] as List<dynamic>)
      .map((e) => NamedRef.fromJson(e as Map<String, dynamic>))
      .toList(),
  country: json['country'] as String?,
  id: (json['id'] as num).toInt(),
  logo: json['logo'] as String?,
  name: json['name'] as String,
  primaryCompetition: json['primary_competition'] == null
      ? null
      : PrimaryCompetitionRef.fromJson(
          json['primary_competition'] as Map<String, dynamic>,
        ),
  recent: (json['recent'] as List<dynamic>)
      .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  sport: Sport.fromJson(json['sport'] as String),
  stadium: json['stadium'] as String?,
  upcoming: (json['upcoming'] as List<dynamic>)
      .map((e) => MatchSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TeamDetailToJson(_TeamDetail instance) =>
    <String, dynamic>{
      'competitions': instance.competitions,
      'country': instance.country,
      'id': instance.id,
      'logo': instance.logo,
      'name': instance.name,
      'primary_competition': instance.primaryCompetition,
      'recent': instance.recent,
      'sport': _$SportEnumMap[instance.sport]!,
      'stadium': instance.stadium,
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
