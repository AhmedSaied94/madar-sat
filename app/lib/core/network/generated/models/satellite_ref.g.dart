// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'satellite_ref.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SatelliteRef _$SatelliteRefFromJson(Map<String, dynamic> json) =>
    _SatelliteRef(
      id: (json['id'] as num).toInt(),
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String,
      orbitalPosition: json['orbital_position'] as num?,
      slug: json['slug'] as String,
    );

Map<String, dynamic> _$SatelliteRefToJson(_SatelliteRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name_ar': instance.nameAr,
      'name_en': instance.nameEn,
      'orbital_position': ?instance.orbitalPosition,
      'slug': instance.slug,
    };
