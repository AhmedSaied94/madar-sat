// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_register_platform.dart';

part 'device_register.freezed.dart';
part 'device_register.g.dart';

@Freezed()
abstract class DeviceRegister with _$DeviceRegister {
  const factory DeviceRegister({
    @JsonKey(name: 'install_id')
    required String installId,
    required DeviceRegisterPlatform platform,
  }) = _DeviceRegister;
  
  factory DeviceRegister.fromJson(Map<String, Object?> json) => _$DeviceRegisterFromJson(json);
}
