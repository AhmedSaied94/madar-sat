// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rights_holder_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RightsHolderDetail _$RightsHolderDetailFromJson(Map<String, dynamic> json) =>
    _RightsHolderDetail(
      carriages: (json['carriages'] as List<dynamic>)
          .map((e) => RightsHolderCarriage.fromJson(e as Map<String, dynamic>))
          .toList(),
      competitions: (json['competitions'] as List<dynamic>)
          .map((e) => NamedRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      id: (json['id'] as num).toInt(),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RightsHolderDetailToJson(_RightsHolderDetail instance) =>
    <String, dynamic>{
      'carriages': instance.carriages,
      'competitions': instance.competitions,
      'id': instance.id,
      'logo': ?instance.logo,
      'name': instance.name,
      'sort_order': ?instance.sortOrder,
    };
