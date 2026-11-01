// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device.dart';
import 'error_body.dart';

part 'envelope_device.freezed.dart';
part 'envelope_device.g.dart';

@Freezed()
abstract class EnvelopeDevice with _$EnvelopeDevice {
  const factory EnvelopeDevice({
    required Device? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeDevice;
  
  factory EnvelopeDevice.fromJson(Map<String, Object?> json) => _$EnvelopeDeviceFromJson(json);
}
