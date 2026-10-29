// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'match_summary.dart';

part 'commentator_detail.freezed.dart';
part 'commentator_detail.g.dart';

@Freezed()
abstract class CommentatorDetail with _$CommentatorDetail {
  const factory CommentatorDetail({
    required String? audio,
    required int id,
    required String? image,
    required String name,
    required List<MatchSummary> upcoming,
  }) = _CommentatorDetail;
  
  factory CommentatorDetail.fromJson(Map<String, Object?> json) => _$CommentatorDetailFromJson(json);
}
