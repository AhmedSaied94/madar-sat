// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'error_body.freezed.dart';
part 'error_body.g.dart';

@Freezed()
abstract class ErrorBody with _$ErrorBody {
  const factory ErrorBody({
    required String code,
    required String message,
  }) = _ErrorBody;
  
  factory ErrorBody.fromJson(Map<String, Object?> json) => _$ErrorBodyFromJson(json);
}
