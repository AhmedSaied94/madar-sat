// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'polarization.dart';

part 'frequency.freezed.dart';
part 'frequency.g.dart';

@Freezed()
abstract class Frequency with _$Frequency {
  const factory Frequency({
    required int mhz,
    required Polarization pol,
    required int sr,
  }) = _Frequency;
  
  factory Frequency.fromJson(Map<String, Object?> json) => _$FrequencyFromJson(json);
}
