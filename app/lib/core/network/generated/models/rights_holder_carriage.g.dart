// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rights_holder_carriage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RightsHolderCarriage _$RightsHolderCarriageFromJson(
  Map<String, dynamic> json,
) => _RightsHolderCarriage(
  access: Access.fromJson(json['access'] as String),
  beam: json['beam'] == null ? null : Beam.fromJson(json['beam'] as String),
  frequencies: (json['frequencies'] as List<dynamic>)
      .map((e) => RightsHolderFrequency.fromJson(e as Map<String, dynamic>))
      .toList(),
  id: (json['id'] as num).toInt(),
  satellites: (json['satellites'] as List<dynamic>)
      .map((e) => SatelliteRef.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RightsHolderCarriageToJson(
  _RightsHolderCarriage instance,
) => <String, dynamic>{
  'access': _$AccessEnumMap[instance.access]!,
  'beam': _$BeamEnumMap[instance.beam],
  'frequencies': instance.frequencies,
  'id': instance.id,
  'satellites': instance.satellites,
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
