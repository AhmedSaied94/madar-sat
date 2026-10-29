// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'competition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Competition _$CompetitionFromJson(Map<String, dynamic> json) => _Competition(
  id: (json['id'] as num).toInt(),
  logo: json['logo'] as String?,
  name: json['name'] as String,
  priority: (json['priority'] as num?)?.toInt(),
  sport: Sport.fromJson(json['sport'] as String),
);

Map<String, dynamic> _$CompetitionToJson(_Competition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'logo': instance.logo,
      'name': instance.name,
      'priority': instance.priority,
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
