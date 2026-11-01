// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_registered.dart';
import 'error_body.dart';

part 'envelope_device_registered.freezed.dart';
part 'envelope_device_registered.g.dart';

@Freezed()
abstract class EnvelopeDeviceRegistered with _$EnvelopeDeviceRegistered {
  const factory EnvelopeDeviceRegistered({
    required DeviceRegistered? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeDeviceRegistered;
  
  factory EnvelopeDeviceRegistered.fromJson(Map<String, Object?> json) => _$EnvelopeDeviceRegisteredFromJson(json);
}
