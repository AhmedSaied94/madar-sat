// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frequency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Frequency _$FrequencyFromJson(Map<String, dynamic> json) => _Frequency(
  mhz: (json['mhz'] as num).toInt(),
  pol: Polarization.fromJson(json['pol'] as String),
  sr: (json['sr'] as num).toInt(),
);

Map<String, dynamic> _$FrequencyToJson(_Frequency instance) =>
    <String, dynamic>{
      'mhz': instance.mhz,
      'pol': _$PolarizationEnumMap[instance.pol]!,
      'sr': instance.sr,
    };

const _$PolarizationEnumMap = {
  Polarization.h: 'H',
  Polarization.v: 'V',
  Polarization.l: 'L',
  Polarization.r: 'R',
  Polarization.$unknown: r'$unknown',
};
