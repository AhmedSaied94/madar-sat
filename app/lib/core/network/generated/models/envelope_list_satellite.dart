// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'satellite.dart';

part 'envelope_list_satellite.freezed.dart';
part 'envelope_list_satellite.g.dart';

@Freezed()
abstract class EnvelopeListSatellite with _$EnvelopeListSatellite {
  const factory EnvelopeListSatellite({
    required List<Satellite>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListSatellite;
  
  factory EnvelopeListSatellite.fromJson(Map<String, Object?> json) => _$EnvelopeListSatelliteFromJson(json);
}
