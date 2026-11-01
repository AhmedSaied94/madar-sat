// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_registered.freezed.dart';
part 'device_registered.g.dart';

@Freezed()
abstract class DeviceRegistered with _$DeviceRegistered {
  const factory DeviceRegistered({
    @JsonKey(name: 'device_id')
    required int deviceId,
    @JsonKey(name: 'device_token')
    required String deviceToken,
  }) = _DeviceRegistered;
  
  factory DeviceRegistered.fromJson(Map<String, Object?> json) => _$DeviceRegisteredFromJson(json);
}
