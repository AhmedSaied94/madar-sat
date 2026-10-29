// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'commentator_ref.freezed.dart';
part 'commentator_ref.g.dart';

@Freezed()
abstract class CommentatorRef with _$CommentatorRef {
  const factory CommentatorRef({
    required String? audio,
    required int id,
    required String? image,
    required String name,
  }) = _CommentatorRef;
  
  factory CommentatorRef.fromJson(Map<String, Object?> json) => _$CommentatorRefFromJson(json);
}
