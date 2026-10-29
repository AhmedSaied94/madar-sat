// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'competition.dart';
import 'error_body.dart';

part 'envelope_list_competition.freezed.dart';
part 'envelope_list_competition.g.dart';

@Freezed()
abstract class EnvelopeListCompetition with _$EnvelopeListCompetition {
  const factory EnvelopeListCompetition({
    required List<Competition>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListCompetition;
  
  factory EnvelopeListCompetition.fromJson(Map<String, Object?> json) => _$EnvelopeListCompetitionFromJson(json);
}
