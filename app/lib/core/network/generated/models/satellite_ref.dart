// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'satellite_ref.freezed.dart';
part 'satellite_ref.g.dart';

@Freezed()
abstract class SatelliteRef with _$SatelliteRef {
  const factory SatelliteRef({
    required int id,
    @JsonKey(name: 'name_ar')
    required String nameAr,
    @JsonKey(name: 'name_en')
    required String nameEn,
    @JsonKey(name: 'orbital_position')
    required num? orbitalPosition,
    required String slug,
  }) = _SatelliteRef;
  
  factory SatelliteRef.fromJson(Map<String, Object?> json) => _$SatelliteRefFromJson(json);
}
