// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'frequency.dart';
import 'kind.dart';

part 'satellite.freezed.dart';
part 'satellite.g.dart';

@Freezed()
abstract class Satellite with _$Satellite {
  const factory Satellite({
    @JsonKey(name: 'best_frequency')
    required Frequency? bestFrequency,
    @JsonKey(name: 'channel_count')
    required int channelCount,
    required int id,
    required Kind kind,
    required String? logo,
    @JsonKey(name: 'name_ar')
    required String nameAr,
    @JsonKey(name: 'name_en')
    required String nameEn,
    @JsonKey(name: 'orbital_position')
    required num? orbitalPosition,
    @JsonKey(name: 'reception_url')
    required String? receptionUrl,
    required String slug,
    @JsonKey(name: 'worst_frequency')
    required Frequency? worstFrequency,
  }) = _Satellite;
  
  factory Satellite.fromJson(Map<String, Object?> json) => _$SatelliteFromJson(json);
}
