// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'team_search_item.dart';

part 'envelope_list_team_search_item.freezed.dart';
part 'envelope_list_team_search_item.g.dart';

@Freezed()
abstract class EnvelopeListTeamSearchItem with _$EnvelopeListTeamSearchItem {
  const factory EnvelopeListTeamSearchItem({
    required List<TeamSearchItem>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListTeamSearchItem;
  
  factory EnvelopeListTeamSearchItem.fromJson(Map<String, Object?> json) => _$EnvelopeListTeamSearchItemFromJson(json);
}
