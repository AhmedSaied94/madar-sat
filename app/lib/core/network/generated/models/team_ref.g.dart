// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamRef _$TeamRefFromJson(Map<String, dynamic> json) => _TeamRef(
  id: (json['id'] as num?)?.toInt(),
  logo: json['logo'] as String?,
  name: json['name'] as String,
);

Map<String, dynamic> _$TeamRefToJson(_TeamRef instance) => <String, dynamic>{
  'id': ?instance.id,
  'logo': ?instance.logo,
  'name': instance.name,
};
