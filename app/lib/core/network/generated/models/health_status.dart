// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_status.freezed.dart';
part 'health_status.g.dart';

@Freezed()
abstract class HealthStatus with _$HealthStatus {
  const factory HealthStatus({
    required String db,
    required String redis,
  }) = _HealthStatus;
  
  factory HealthStatus.fromJson(Map<String, Object?> json) => _$HealthStatusFromJson(json);
}
