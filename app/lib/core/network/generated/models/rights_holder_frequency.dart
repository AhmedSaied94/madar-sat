// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'polarization.dart';

part 'rights_holder_frequency.freezed.dart';
part 'rights_holder_frequency.g.dart';

@Freezed()
abstract class RightsHolderFrequency with _$RightsHolderFrequency {
  const factory RightsHolderFrequency({
    @JsonKey(name: 'is_primary')
    required bool isPrimary,
    required int mhz,
    required Polarization pol,
    required int sr,
  }) = _RightsHolderFrequency;
  
  factory RightsHolderFrequency.fromJson(Map<String, Object?> json) => _$RightsHolderFrequencyFromJson(json);
}
