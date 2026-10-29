// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'commentator_detail.dart';
import 'error_body.dart';

part 'envelope_commentator_detail.freezed.dart';
part 'envelope_commentator_detail.g.dart';

@Freezed()
abstract class EnvelopeCommentatorDetail with _$EnvelopeCommentatorDetail {
  const factory EnvelopeCommentatorDetail({
    required CommentatorDetail? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeCommentatorDetail;
  
  factory EnvelopeCommentatorDetail.fromJson(Map<String, Object?> json) => _$EnvelopeCommentatorDetailFromJson(json);
}
