// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'primary_competition_ref.freezed.dart';
part 'primary_competition_ref.g.dart';

/// ``{id, name}`` — a team's primary competition in search results.
@Freezed()
abstract class PrimaryCompetitionRef with _$PrimaryCompetitionRef {
  const factory PrimaryCompetitionRef({
    required int id,
    required String name,
  }) = _PrimaryCompetitionRef;
  
  factory PrimaryCompetitionRef.fromJson(Map<String, Object?> json) => _$PrimaryCompetitionRefFromJson(json);
}
