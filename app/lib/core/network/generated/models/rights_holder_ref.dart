// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'satellite_ref.dart';

part 'rights_holder_ref.freezed.dart';
part 'rights_holder_ref.g.dart';

/// A rights holder on S8: where it can be received and how many competitions it carries.
@Freezed()
abstract class RightsHolderRef with _$RightsHolderRef {
  const factory RightsHolderRef({
    @JsonKey(name: 'competition_count')
    required int competitionCount,
    required int id,
    required String? logo,
    required String name,
    required List<SatelliteRef> satellites,
  }) = _RightsHolderRef;
  
  factory RightsHolderRef.fromJson(Map<String, Object?> json) => _$RightsHolderRefFromJson(json);
}
