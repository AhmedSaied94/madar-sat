// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'competition_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CompetitionRef _$CompetitionRefFromJson(Map<String, dynamic> json) =>
    _CompetitionRef(
      id: (json['id'] as num?)?.toInt(),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      priority: (json['priority'] as num?)?.toInt(),
      stage: json['stage'] as String?,
    );

Map<String, dynamic> _$CompetitionRefToJson(_CompetitionRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'logo': instance.logo,
      'name': instance.name,
      'priority': instance.priority,
      'stage': instance.stage,
    };
