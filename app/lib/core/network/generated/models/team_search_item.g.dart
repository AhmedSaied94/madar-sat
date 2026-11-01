// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_search_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamSearchItem _$TeamSearchItemFromJson(Map<String, dynamic> json) =>
    _TeamSearchItem(
      country: json['country'] as String?,
      id: (json['id'] as num).toInt(),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      primaryCompetition: json['primary_competition'] == null
          ? null
          : PrimaryCompetitionRef.fromJson(
              json['primary_competition'] as Map<String, dynamic>,
            ),
      sport: Sport.fromJson(json['sport'] as String),
    );

Map<String, dynamic> _$TeamSearchItemToJson(_TeamSearchItem instance) =>
    <String, dynamic>{
      'country': ?instance.country,
      'id': instance.id,
      'logo': ?instance.logo,
      'name': instance.name,
      'primary_competition': ?instance.primaryCompetition,
      'sport': _$SportEnumMap[instance.sport]!,
    };

const _$SportEnumMap = {
  Sport.football: 'football',
  Sport.basketball: 'basketball',
  Sport.handball: 'handball',
  Sport.volleyball: 'volleyball',
  Sport.tennis: 'tennis',
  Sport.$unknown: r'$unknown',
};
