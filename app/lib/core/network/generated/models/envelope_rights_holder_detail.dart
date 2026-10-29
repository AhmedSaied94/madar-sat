// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'rights_holder_detail.dart';

part 'envelope_rights_holder_detail.freezed.dart';
part 'envelope_rights_holder_detail.g.dart';

@Freezed()
abstract class EnvelopeRightsHolderDetail with _$EnvelopeRightsHolderDetail {
  const factory EnvelopeRightsHolderDetail({
    required RightsHolderDetail? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeRightsHolderDetail;
  
  factory EnvelopeRightsHolderDetail.fromJson(Map<String, Object?> json) => _$EnvelopeRightsHolderDetailFromJson(json);
}
