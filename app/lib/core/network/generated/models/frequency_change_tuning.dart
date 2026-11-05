// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'polarization.dart';

part 'frequency_change_tuning.freezed.dart';
part 'frequency_change_tuning.g.dart';

@Freezed()
abstract class FrequencyChangeTuning with _$FrequencyChangeTuning {
  const factory FrequencyChangeTuning({
    @JsonKey(name: 'frequency_mhz')
    required int frequencyMhz,
    required Polarization polarization,
    @JsonKey(name: 'symbol_rate')
    required int symbolRate,
  }) = _FrequencyChangeTuning;
  
  factory FrequencyChangeTuning.fromJson(Map<String, Object?> json) => _$FrequencyChangeTuningFromJson(json);
}
