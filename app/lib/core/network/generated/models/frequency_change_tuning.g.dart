// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frequency_change_tuning.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FrequencyChangeTuning _$FrequencyChangeTuningFromJson(
  Map<String, dynamic> json,
) => _FrequencyChangeTuning(
  frequencyMhz: (json['frequency_mhz'] as num).toInt(),
  polarization: Polarization.fromJson(json['polarization'] as String),
  symbolRate: (json['symbol_rate'] as num).toInt(),
);

Map<String, dynamic> _$FrequencyChangeTuningToJson(
  _FrequencyChangeTuning instance,
) => <String, dynamic>{
  'frequency_mhz': instance.frequencyMhz,
  'polarization': _$PolarizationEnumMap[instance.polarization]!,
  'symbol_rate': instance.symbolRate,
};

const _$PolarizationEnumMap = {
  Polarization.h: 'H',
  Polarization.v: 'V',
  Polarization.l: 'L',
  Polarization.r: 'R',
  Polarization.$unknown: r'$unknown',
};
