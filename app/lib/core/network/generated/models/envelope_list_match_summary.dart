// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_body.dart';
import 'match_summary.dart';

part 'envelope_list_match_summary.freezed.dart';
part 'envelope_list_match_summary.g.dart';

@Freezed()
abstract class EnvelopeListMatchSummary with _$EnvelopeListMatchSummary {
  const factory EnvelopeListMatchSummary({
    required List<MatchSummary>? data,
    required ErrorBody? error,
    required dynamic meta,
    required bool success,
  }) = _EnvelopeListMatchSummary;
  
  factory EnvelopeListMatchSummary.fromJson(Map<String, Object?> json) => _$EnvelopeListMatchSummaryFromJson(json);
}
