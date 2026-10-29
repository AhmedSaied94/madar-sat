// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'rights_holder.dart';

part 'envelope_list_rights_holder.freezed.dart';
part 'envelope_list_rights_holder.g.dart';

@Freezed()
abstract class EnvelopeListRightsHolder with _$EnvelopeListRightsHolder {
  const factory EnvelopeListRightsHolder({
    required List<RightsHolder>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListRightsHolder;
  
  factory EnvelopeListRightsHolder.fromJson(Map<String, Object?> json) => _$EnvelopeListRightsHolderFromJson(json);
}
