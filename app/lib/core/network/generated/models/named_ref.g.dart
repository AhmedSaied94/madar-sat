// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'named_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NamedRef _$NamedRefFromJson(Map<String, dynamic> json) => _NamedRef(
  id: (json['id'] as num).toInt(),
  logo: json['logo'] as String?,
  name: json['name'] as String,
);

Map<String, dynamic> _$NamedRefToJson(_NamedRef instance) => <String, dynamic>{
  'id': instance.id,
  'logo': ?instance.logo,
  'name': instance.name,
};
