// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'satellite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Satellite _$SatelliteFromJson(Map<String, dynamic> json) => _Satellite(
  bestFrequency: json['best_frequency'] == null
      ? null
      : Frequency.fromJson(json['best_frequency'] as Map<String, dynamic>),
  channelCount: (json['channel_count'] as num).toInt(),
  id: (json['id'] as num).toInt(),
  kind: Kind.fromJson(json['kind'] as String),
  logo: json['logo'] as String?,
  nameAr: json['name_ar'] as String,
  nameEn: json['name_en'] as String,
  orbitalPosition: json['orbital_position'] as num?,
  receptionUrl: json['reception_url'] as String?,
  slug: json['slug'] as String,
  worstFrequency: json['worst_frequency'] == null
      ? null
      : Frequency.fromJson(json['worst_frequency'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SatelliteToJson(_Satellite instance) =>
    <String, dynamic>{
      'best_frequency': instance.bestFrequency,
      'channel_count': instance.channelCount,
      'id': instance.id,
      'kind': _$KindEnumMap[instance.kind]!,
      'logo': instance.logo,
      'name_ar': instance.nameAr,
      'name_en': instance.nameEn,
      'orbital_position': instance.orbitalPosition,
      'reception_url': instance.receptionUrl,
      'slug': instance.slug,
      'worst_frequency': instance.worstFrequency,
    };

const _$KindEnumMap = {
  Kind.satellite: 'satellite',
  Kind.terrestrial: 'terrestrial',
  Kind.platform: 'platform',
  Kind.$unknown: r'$unknown',
};
