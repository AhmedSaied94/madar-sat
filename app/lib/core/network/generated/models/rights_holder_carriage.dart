// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'access.dart';
import 'beam.dart';
import 'rights_holder_frequency.dart';
import 'satellite_ref.dart';

part 'rights_holder_carriage.freezed.dart';
part 'rights_holder_carriage.g.dart';

@Freezed()
abstract class RightsHolderCarriage with _$RightsHolderCarriage {
  const factory RightsHolderCarriage({
    required Access access,
    required Beam? beam,
    required List<RightsHolderFrequency> frequencies,
    required int id,
    required List<SatelliteRef> satellites,
  }) = _RightsHolderCarriage;
  
  factory RightsHolderCarriage.fromJson(Map<String, Object?> json) => _$RightsHolderCarriageFromJson(json);
}
