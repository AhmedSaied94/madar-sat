// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rights_holder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RightsHolder _$RightsHolderFromJson(Map<String, dynamic> json) =>
    _RightsHolder(
      id: (json['id'] as num).toInt(),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RightsHolderToJson(_RightsHolder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'logo': instance.logo,
      'name': instance.name,
      'sort_order': instance.sortOrder,
    };
