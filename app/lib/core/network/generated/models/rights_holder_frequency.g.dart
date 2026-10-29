// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rights_holder_frequency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RightsHolderFrequency _$RightsHolderFrequencyFromJson(
  Map<String, dynamic> json,
) => _RightsHolderFrequency(
  isPrimary: json['is_primary'] as bool,
  mhz: (json['mhz'] as num).toInt(),
  pol: Polarization.fromJson(json['pol'] as String),
  sr: (json['sr'] as num).toInt(),
);

Map<String, dynamic> _$RightsHolderFrequencyToJson(
  _RightsHolderFrequency instance,
) => <String, dynamic>{
  'is_primary': instance.isPrimary,
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
