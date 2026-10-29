// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'health_status.dart';

part 'envelope_health_status.freezed.dart';
part 'envelope_health_status.g.dart';

@Freezed()
abstract class EnvelopeHealthStatus with _$EnvelopeHealthStatus {
  const factory EnvelopeHealthStatus({
    required HealthStatus? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeHealthStatus;
  
  factory EnvelopeHealthStatus.fromJson(Map<String, Object?> json) => _$EnvelopeHealthStatusFromJson(json);
}
