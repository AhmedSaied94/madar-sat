// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';

part 'error_envelope.freezed.dart';
part 'error_envelope.g.dart';

/// The body of every 4xx/5xx response.
@Freezed()
abstract class ErrorEnvelope with _$ErrorEnvelope {
  const factory ErrorEnvelope({
    required dynamic data,
    required ErrorBody error,
    required dynamic meta,
    required bool success,
  }) = _ErrorEnvelope;
  
  factory ErrorEnvelope.fromJson(Map<String, Object?> json) => _$ErrorEnvelopeFromJson(json);
}
