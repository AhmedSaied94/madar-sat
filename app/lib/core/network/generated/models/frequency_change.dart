// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'frequency_change_tuning.dart';

part 'frequency_change.freezed.dart';
part 'frequency_change.g.dart';

/// Stays empty until D6 fills it; the type is fixed now so the app's section can be tested.
@Freezed()
abstract class FrequencyChange with _$FrequencyChange {
  const factory FrequencyChange({
    @JsonKey(name: 'detected_at')
    required DateTime detectedAt,

    /// The name has been replaced because it contains a keyword. Original name: `new`.
    @JsonKey(name: 'new')
    required FrequencyChangeTuning newValue,
    required FrequencyChangeTuning old,
  }) = _FrequencyChange;
  
  factory FrequencyChange.fromJson(Map<String, Object?> json) => _$FrequencyChangeFromJson(json);
}
