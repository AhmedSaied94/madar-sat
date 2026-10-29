// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_carriage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChannelCarriage _$ChannelCarriageFromJson(Map<String, dynamic> json) =>
    _ChannelCarriage(
      access: json['access'] == null
          ? null
          : Access.fromJson(json['access'] as String),
      beam: json['beam'] == null ? null : Beam.fromJson(json['beam'] as String),
      category: json['category'] == null
          ? null
          : Category.fromJson(json['category'] as String),
      country: json['country'] as String?,
      displayName: json['display_name'] as String?,
      frequency: json['frequency'] == null
          ? null
          : Frequency.fromJson(json['frequency'] as Map<String, dynamic>),
      frequencyChangedAt: json['frequency_changed_at'] == null
          ? null
          : DateTime.parse(json['frequency_changed_at'] as String),
      frequencyNote: json['frequency_note'] as String?,
      id: (json['id'] as num).toInt(),
      kind: Kind.fromJson(json['kind'] as String),
      logo: json['logo'] as String?,
      name: json['name'] as String,
      package: json['package'] as String?,
      provider: json['provider'] as String?,
      satellite: json['satellite'] == null
          ? null
          : SatelliteRef.fromJson(json['satellite'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ChannelCarriageToJson(_ChannelCarriage instance) =>
    <String, dynamic>{
      'access': _$AccessEnumMap[instance.access],
      'beam': _$BeamEnumMap[instance.beam],
      'category': _$CategoryEnumMap[instance.category],
      'country': instance.country,
      'display_name': instance.displayName,
      'frequency': instance.frequency,
      'frequency_changed_at': instance.frequencyChangedAt?.toIso8601String(),
      'frequency_note': instance.frequencyNote,
      'id': instance.id,
      'kind': _$KindEnumMap[instance.kind]!,
      'logo': instance.logo,
      'name': instance.name,
      'package': instance.package,
      'provider': instance.provider,
      'satellite': instance.satellite,
    };

const _$AccessEnumMap = {
  Access.free: 'free',
  Access.encrypted: 'encrypted',
  Access.$unknown: r'$unknown',
};

const _$BeamEnumMap = {
  Beam.wide: 'wide',
  Beam.narrow: 'narrow',
  Beam.$unknown: r'$unknown',
};

const _$CategoryEnumMap = {
  Category.sports: 'sports',
  Category.entertainment: 'entertainment',
  Category.$unknown: r'$unknown',
};

const _$KindEnumMap = {
  Kind.satellite: 'satellite',
  Kind.terrestrial: 'terrestrial',
  Kind.platform: 'platform',
  Kind.$unknown: r'$unknown',
};
