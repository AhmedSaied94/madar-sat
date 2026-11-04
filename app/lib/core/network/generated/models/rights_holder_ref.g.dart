// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rights_holder_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RightsHolderRef _$RightsHolderRefFromJson(Map<String, dynamic> json) =>
    _RightsHolderRef(
      competitionCount: (json['competition_count'] as num).toInt(),
      id: (json['id'] as num).toInt(),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      satellites: (json['satellites'] as List<dynamic>)
          .map((e) => SatelliteRef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RightsHolderRefToJson(_RightsHolderRef instance) =>
    <String, dynamic>{
      'competition_count': instance.competitionCount,
      'id': instance.id,
      'logo': ?instance.logo,
      'name': instance.name,
      'satellites': instance.satellites,
    };
